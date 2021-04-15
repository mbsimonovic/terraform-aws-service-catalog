package mgmt

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/aws-service-catalog/test"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

func TestOpenvpnServer(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "us-east-2")
	//os.Setenv("SKIP_build_ami", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_cleanup", "true")
	//os.Setenv("SKIP_cleanup_keypair", "true")
	//os.Setenv("SKIP_cleanup_ami", "true")

	testFolder := "../../examples/for-learning-and-testing/mgmt/openvpn-server"
	branchName := git.GetCurrentBranchName(t)

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiId)
	})

	defer test_structure.RunTestStage(t, "cleanup_keypair", func() {
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
		aws.DeleteEC2KeyPair(t, awsKeyPair)
	})

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		awsRegion := aws.GetRandomStableRegion(t, test.RegionsForEc2Tests, nil)
		uniqueId := random.UniqueId()
		name := fmt.Sprintf("openvpn-server-%s", uniqueId)
		awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueId)
		s3BucketName := "openvpn-test-" + strings.ToLower(uniqueId)

		packerOptions := &packer.Options{
			Template: "../../modules/mgmt/openvpn-server/openvpn-server.json",
			Vars: map[string]string{
				"aws_region":          awsRegion,
				"service_catalog_ref": branchName,
				"version_tag":         branchName,
				"encrypt_boot":        "false",
			},
			MaxRetries:         3,
			TimeBetweenRetries: 5 * time.Second,
		}

		amiId := packer.BuildArtifact(t, packerOptions)

		test_structure.SaveString(t, testFolder, "region", awsRegion)
		test_structure.SaveString(t, testFolder, "name", name)
		test_structure.SaveString(t, testFolder, "s3BucketName", s3BucketName)
		test_structure.SaveArtifactID(t, testFolder, amiId)
		test_structure.SaveEc2KeyPair(t, testFolder, awsKeyPair)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		s3BucketName := test_structure.LoadString(t, testFolder, "s3BucketName")
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
		name := test_structure.LoadString(t, testFolder, "name")

		terraformOptions := &terraform.Options{
			TerraformDir: testFolder,

			Vars: map[string]interface{}{
				"aws_region":            awsRegion,
				"name":                  name,
				"ami_version_tag":       branchName,
				"base_domain_name":      "gruntwork.in",
				"base_domain_name_tags": test.DomainNameTagsForTest,
				"keypair_name":          awsKeyPair.Name,
				"backup_bucket_name":    s3BucketName,
				"instance_type":         "c5.large",
				"vpn_search_domains": []string{
					"example.com",
					"foo.com",
				},
				"additional_vpn_route_cidr_blocks": []string{
					"192.168.0.0/24",
				},
			},
		}

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		ip := terraform.OutputRequired(t, terraformOptions, "public_ip")
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
		checkOpenVPNServer(t, ip, "ubuntu", awsKeyPair)
	})
}

func checkOpenVPNServer(t *testing.T, ip string, sshUsername string, keyPair *aws.Ec2Keypair) {
	publicHost := ssh.Host{
		Hostname:    ip,
		SshUserName: sshUsername,
		SshKeyPair:  keyPair.KeyPair,
	}

	// Wait up to 20 minutes to allow for generating certificates
	output := retry.DoWithRetry(
		t,
		fmt.Sprintf("Check for openvpn-admin processes on %s", ip),
		40,
		30*time.Second,
		func() (string, error) {
			return ssh.CheckSshCommandE(t, publicHost, "/usr/bin/pgrep openvpn-admin")
		},
	)
	numProcsExpected := 2
	lines := strings.Split(strings.Trim(output, "\n"), "\n")
	require.Lenf(t, lines, numProcsExpected, "Expected to find %d openvpn-admin processes but found %d\n", numProcsExpected, len(lines))
}
