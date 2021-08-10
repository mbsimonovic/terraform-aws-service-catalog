package services

import (
	"errors"
	"fmt"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/aws-service-catalog/test"
	"github.com/stretchr/testify/assert"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func waitUntilSSHAvailable(t *testing.T, host ssh.Host, maxRetries int, timeBetweenRetries time.Duration) {
	retry.DoWithRetry(
		t,
		fmt.Sprintf("SSH to public host %s", host.Hostname),
		maxRetries,
		timeBetweenRetries,
		func() (string, error) {
			return "", ssh.CheckSshConnectionE(t, host)
		},
	)
}

func sshToHostAndRunCommand(
	t *testing.T,
	terratestOptions *terraform.Options,
	sshUserName string,
	command string,
	keyPair *aws.Ec2Keypair,
) (string, error) {
	publicIp, err := terraform.OutputE(t, terratestOptions, "ec2_instance_public_ip")
	if err != nil {
		return "", fmt.Errorf("Failed to get Terraform output %s: %s\n", "ec2_instance_public_ip", err.Error())
	}
	if publicIp == "" {
		return "", fmt.Errorf("Got empty value for Terraform output %s", "ec2_instance_public_ip")
	}

	host := ssh.Host{
		Hostname:    publicIp,
		SshUserName: sshUserName,
		SshKeyPair:  keyPair.KeyPair,
	}
	return ssh.CheckSshCommandE(t, host, command)
}

func unmountVolume(
	t *testing.T,
	terratestOptions *terraform.Options,
	region string,
	volumeIdOutputName string,
	deviceNameOutputName string,
	mountPointOutputName string,
	sshUserName string,
	keyPair *aws.Ec2Keypair,
) {
	// terraform.OutputMap
	volumeId := terraform.Output(t, terratestOptions, volumeIdOutputName)
	deviceName := terraform.Output(t, terratestOptions, deviceNameOutputName)
	mountPoint := terraform.Output(t, terratestOptions, mountPointOutputName)

	// logger.Logf(t, "SSH to redeployed EC2 Instance and unmount volume %s with ID %s.", volumeIdOutputName, volumeId)
	fmt.Printf("SSH to redeployed EC2 Instance and unmount volume %s with ID %s.", volumeIdOutputName, volumeId)

	command := fmt.Sprintf("sudo unmount-ebs-volume --aws-region %s --volume-id %s --device-name %s --mount-point %s", region, volumeId, deviceName, mountPoint)
	sshToHostAndRunCommand(t, terratestOptions, sshUserName, command, keyPair)
}

func TestEc2Instance(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "eu-west-1")
	// os.Setenv("SKIP_build_ami", "true")
	// os.Setenv("SKIP_deploy_terraform", "true")
	// os.Setenv("SKIP_validate", "true")
	// os.Setenv("SKIP_cleanup", "true")
	// os.Setenv("SKIP_cleanup_keypair", "true")
	// os.Setenv("SKIP_cleanup_ami", "true")

	workingDir := filepath.Join(".", "stages", t.Name())
	branchName := git.GetCurrentBranchName(t)

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		amiId := test_structure.LoadArtifactID(t, workingDir)
		awsRegion := test_structure.LoadString(t, workingDir, "region")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiId)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		awsRegion := aws.GetRandomStableRegion(t, test.RegionsForEc2Tests, nil)

		packerOptions := &packer.Options{
			Template: "../../modules/services/ec2-instance/ec2-instance.pkr.hcl",
			Vars: map[string]string{
				"aws_region":          awsRegion,
				"service_catalog_ref": branchName,
				"version_tag":         branchName,
			},
			MaxRetries:         3,
			TimeBetweenRetries: 5 * time.Second,
		}

		amiId := packer.BuildArtifact(t, packerOptions)

		test_structure.SaveString(t, workingDir, "region", awsRegion)
		test_structure.SaveArtifactID(t, workingDir, amiId)
	})

	// Spawn two sub tests in parallel using the same AMI. Note that we wrap the sub tests in a synchronous test group
	// so that the AMI cleanup stage waits for the two subtests to finish.
	t.Run("group", func(t *testing.T) {
		t.Run("WithDomain", func(t *testing.T) {
			t.Parallel()
			testEc2InstanceHelper(t, workingDir, branchName, test.BaseDomainForTest)
		})
		t.Run("WithoutDomain", func(t *testing.T) {
			t.Parallel()
			testEc2InstanceHelper(t, workingDir, branchName, "")
		})
	})
}

func testEc2InstanceHelper(t *testing.T, parentWorkingDir string, branchName string, domainName string) {
	childWorkingDir := filepath.Join(".", "stages", t.Name())
	terraformDir := test_structure.CopyTerraformFolderToTemp(t, "../..", "examples/for-learning-and-testing/services/ec2-instance")

	defer test_structure.RunTestStage(t, "cleanup_keypair", func() {
		awsKeyPair := test_structure.LoadEc2KeyPair(t, childWorkingDir)
		aws.DeleteEC2KeyPair(t, awsKeyPair)
	})

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, childWorkingDir)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		name := fmt.Sprintf("ec2-instance-%s", random.UniqueId())
		awsRegion := test_structure.LoadString(t, parentWorkingDir, "region")
		uniqueId := random.UniqueId()
		awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueId)

		terraformOptions := test.CreateBaseTerraformOptions(t, terraformDir, awsRegion)
		terraformOptions.Vars["aws_region"] = awsRegion
		terraformOptions.Vars["name"] = name
		terraformOptions.Vars["ami_version_tag"] = branchName
		terraformOptions.Vars["base_domain_name_tags"] = test.DomainNameTagsForTest
		terraformOptions.Vars["keypair_name"] = awsKeyPair.Name

		if domainName == "" {
			terraformOptions.Vars["create_dns_record"] = false
		} else {
			terraformOptions.Vars["create_dns_record"] = true
			terraformOptions.Vars["domain_name"] = domainName
		}

		test_structure.SaveTerraformOptions(t, childWorkingDir, terraformOptions)
		test_structure.SaveEc2KeyPair(t, childWorkingDir, awsKeyPair)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, childWorkingDir)
		awsKeyPair := test_structure.LoadEc2KeyPair(t, childWorkingDir)
		ip := terraform.OutputRequired(t, terraformOptions, "ec2_instance_public_ip")
		waitUntilSSHAvailable(t, ssh.Host{Hostname: ip, SshUserName: "ubuntu", SshKeyPair: awsKeyPair.KeyPair}, 10, 30*time.Second)
	})

	test_structure.RunTestStage(t, "validate", func() {
		// Load the Terraform Options saved by the earlier deploy_terraform stage
		terraformOptions := test_structure.LoadTerraformOptions(t, childWorkingDir)

		awsRegion := test_structure.LoadString(t, parentWorkingDir, "region")

		// Load the keypair we saved before we ran terraform
		keyPair := test_structure.LoadEc2KeyPair(t, childWorkingDir)

		// Run `terraform output` to get the value of an output variable
		instancePublicIpWithPermissions := terraform.OutputRequired(t, terraformOptions, "ec2_instance_public_ip")

		instanceIdWithPermissions := terraform.OutputRequired(t, terraformOptions, "ec2_instance_instance_id")

		sshUserName := "ubuntu"

		// Host details used to connect to the host
		hostWithPermissions := ssh.Host{
			Hostname:    instancePublicIpWithPermissions,
			SshUserName: sshUserName,
			SshKeyPair:  keyPair.KeyPair,
		}

		waitUntilSSHAvailable(t, hostWithPermissions, 30, 5*time.Second)

		fileName := "/mnt/demo/demo-file.txt"
		demoFile := retry.DoWithRetry(
			t,
			fmt.Sprintf("Getting %s from %s", fileName, hostWithPermissions.Hostname),
			30,
			5*time.Second,
			func() (string, error) {

				demoFile, err := aws.FetchContentsOfFileFromInstanceE(t,
					terraformOptions.Vars["aws_region"].(string),
					sshUserName,
					keyPair,
					instanceIdWithPermissions,
					true,
					fileName)

				if err != nil {
					return "", err
				}

				if !strings.Contains(demoFile, "Hello, World") {
					return "", errors.New("did not find 'Hello, World'")
				} else {
					return demoFile, nil
				}

			},
		)

		assert.Contains(t, demoFile, "Hello, World")

		unmountVolume(t, terraformOptions, awsRegion, "ec2_instance_volume_id_1", "ec2_instance_volume_device_name_1", "ec2_instance_volume_mount_point_1", sshUserName, keyPair)

		demoFile, err := aws.FetchContentsOfFileFromInstanceE(t,
			terraformOptions.Vars["aws_region"].(string),
			sshUserName,
			keyPair,
			instanceIdWithPermissions,
			true,
			fileName)

		// We expect this to error because the file no longer exists (the volume has been unmounted)
		assert.EqualError(t, err, "Process exited with status 1")
	})

}
