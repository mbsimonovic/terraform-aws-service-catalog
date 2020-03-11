package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestBastionHost(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "eu-west-1")
	// os.Setenv("SKIP_build_ami", "true")
	// os.Setenv("SKIP_deploy_terraform", "true")
	// os.Setenv("SKIP_validate", "true")
	// os.Setenv("SKIP_cleanup", "true")
	// os.Setenv("SKIP_cleanup_ami", "true")

	testFolder := "../examples/for-learning-and-testing/mgmt/bastion-host"

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiId)
	})

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
		aws.DeleteEC2KeyPair(t, awsKeyPair)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		branchName := git.GetCurrentBranchName(t)
		awsRegion := aws.GetRandomRegion(t, acmRegionsForTest, nil)

		packerOptions := &packer.Options{
			Template: "../modules/mgmt/bastion-host/bastion-host.json",
			Vars: map[string]string{
				"aws_region":          awsRegion,
				"service_catalog_ref": branchName,
				"version_tag":         branchName,
			},
			MaxRetries:         3,
			TimeBetweenRetries: 5 * time.Second,
		}

		amiId := packer.BuildArtifact(t, packerOptions)

		test_structure.SaveString(t, testFolder, "region", awsRegion)
		test_structure.SaveArtifactID(t, testFolder, amiId)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		name := fmt.Sprintf("bastion-host-%s", random.UniqueId())
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueId := random.UniqueId()
		awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueId)

		terraformOptions := &terraform.Options{
			TerraformDir: testFolder,

			Vars: map[string]interface{}{
				"aws_region":            awsRegion,
				"name":                  name,
				"ami_id":                amiId,
				"domain_name":           baseDomainForTest,
				"base_domain_name_tags": domainNameTagsForTest,
				"keypair_name":          awsKeyPair.Name,
			},
		}

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
		test_structure.SaveEc2KeyPair(t, testFolder, awsKeyPair)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
		testSSH(t, terraformOptions, awsKeyPair)
	})

}

func testSSH(t *testing.T, terraformOptions *terraform.Options, keyPair *aws.Ec2Keypair) {
	ip := terraform.OutputRequired(t, terraformOptions, "bastion_host_public_ip")

	publicHost := ssh.Host{
		Hostname:    ip,
		SshUserName: "ubuntu",
		SshKeyPair:  keyPair.KeyPair,
	}

	retry.DoWithRetry(
		t,
		fmt.Sprintf("SSH to public host %s", ip),
		10,
		30*time.Second,
		func() (string, error) {
			return "", ssh.CheckSshConnectionE(t, publicHost)
		},
	)
}
