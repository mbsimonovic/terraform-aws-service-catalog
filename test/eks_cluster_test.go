package test

import (
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/git"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var defaultDomainTagFilterForTest = []map[string]string{
	map[string]string{
		"key":   "shared-management-with-kubernetes",
		"value": "true",
	},
}

const expectedEksNodeCount = 1

func TestEksCluster(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_build_ami", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate_cluster", "true")
	//os.Setenv("SKIP_deploy_core_services", "true")
	//os.Setenv("SKIP_cleanup_core_services", "true")
	//os.Setenv("SKIP_cleanup", "true")
	//os.Setenv("SKIP_cleanup_keypair", "true")
	//os.Setenv("SKIP_cleanup_ami", "true")

	testFolder := "../examples/for-learning-and-testing/services/eks-cluster"
	coreServicesTestFolder := "../examples/for-learning-and-testing/services/eks-core-services"

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiId)
	})

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)
		aws.DeleteEC2KeyPair(t, awsKeyPair)
	})

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		// us-west-1 does not support EKS
		awsRegion := aws.GetRandomStableRegion(t, regionsForEc2Tests, []string{"us-west-1"})
		test_structure.SaveString(t, testFolder, "region", awsRegion)

		branchName := git.GetCurrentBranchName(t)
		packerOptions := &packer.Options{
			Template: "../modules/services/eks-cluster/eks-node-al2.json",
			Vars: map[string]string{
				"aws_region":          awsRegion,
				"service_catalog_ref": branchName,
				"version_tag":         branchName,
			},
			MaxRetries:         3,
			TimeBetweenRetries: 5 * time.Second,
		}

		amiId := packer.BuildArtifact(t, packerOptions)
		test_structure.SaveArtifactID(t, testFolder, amiId)

		uniqueID := random.UniqueId()
		clusterName := fmt.Sprintf("eks-service-catalog-%s", strings.ToLower(uniqueID))
		test_structure.SaveString(t, testFolder, "clusterName", clusterName)

		awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)
		test_structure.SaveEc2KeyPair(t, testFolder, awsKeyPair)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		amiId := test_structure.LoadArtifactID(t, testFolder)
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		clusterName := test_structure.LoadString(t, testFolder, "clusterName")
		awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)

		terraformOptions := createBaseTerraformOptions(t, testFolder, awsRegion)
		terraformOptions.Vars["cluster_name"] = clusterName
		terraformOptions.Vars["cluster_instance_ami_id"] = amiId
		terraformOptions.Vars["keypair_name"] = awsKeyPair.Name

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
		terraform.InitAndApply(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate_cluster", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		eksClusterArn := terraform.OutputRequired(t, terraformOptions, "eks_cluster_arn")

		tmpKubeConfigPath := configureKubectlForEKSCluster(t, eksClusterArn)
		defer os.Remove(tmpKubeConfigPath)
		kubectlOptions := k8s.NewKubectlOptions("", tmpKubeConfigPath, "")

		kubeWaitUntilNumNodes(t, kubectlOptions, expectedEksNodeCount, 30, 10*time.Second)
		k8s.WaitUntilAllNodesReady(t, kubectlOptions, 30, 10*time.Second)
		readyNodes := k8s.GetReadyNodes(t, kubectlOptions)
		assert.Equal(t, len(readyNodes), expectedEksNodeCount)
	})

	defer test_structure.RunTestStage(t, "cleanup_core_services", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, coreServicesTestFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_core_services", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		clusterName := test_structure.LoadString(t, testFolder, "clusterName")
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)

		eksClusterIRSAConfig := terraform.OutputMap(t, terraformOptions, "eks_iam_role_for_service_accounts_config")
		eksClusterVpcID := terraform.Output(t, terraformOptions, "eks_cluster_vpc_id")
		eksPrivateSubnetID := terraform.Output(t, terraformOptions, "private_subnet_id")
		eksClusterFargateRole := terraform.Output(t, terraformOptions, "eks_default_fargate_execution_role_arn")

		coreServicesOptions := createBaseTerraformOptions(t, coreServicesTestFolder, awsRegion)
		coreServicesOptions.Vars["eks_cluster_name"] = clusterName
		coreServicesOptions.Vars["vpc_id"] = eksClusterVpcID
		coreServicesOptions.Vars["worker_vpc_subnet_ids"] = []string{eksPrivateSubnetID}
		coreServicesOptions.Vars["eks_iam_role_for_service_accounts_config"] = eksClusterIRSAConfig
		coreServicesOptions.Vars["external_dns_route53_hosted_zone_tag_filters"] = defaultDomainTagFilterForTest
		coreServicesOptions.Vars["pod_execution_iam_role_arn"] = eksClusterFargateRole
		test_structure.SaveTerraformOptions(t, coreServicesTestFolder, coreServicesOptions)

		terraform.InitAndApply(t, coreServicesOptions)
	})

	// TODO: All the core services will be tested when we introduce k8s-service
}

func configureKubectlForEKSCluster(t *testing.T, eksClusterArn string) string {
	tmpKubeConfigFile, err := ioutil.TempFile("", "")
	require.NoError(t, err)
	tmpKubeConfigFile.Close()
	tmpKubeConfigPath := tmpKubeConfigFile.Name()

	command := shell.Command{
		Command: "kubergrunt",
		Args: []string{
			"eks",
			"configure",
			"--eks-cluster-arn", eksClusterArn,
			"--kubeconfig", tmpKubeConfigPath,
		},
	}
	shell.RunCommand(t, command)
	return tmpKubeConfigPath
}

// kubeWaitUntilNumNodes continuously polls the Kubernetes cluster until there are the expected number of nodes
// registered (regardless of readiness).
func kubeWaitUntilNumNodes(t *testing.T, kubectlOptions *k8s.KubectlOptions, numNodes int, retries int, sleepBetweenRetries time.Duration) {
	statusMsg := fmt.Sprintf("Wait for %d Kube Nodes to be registered.", numNodes)
	message, err := retry.DoWithRetryE(
		t,
		statusMsg,
		retries,
		sleepBetweenRetries,
		func() (string, error) {
			nodes, err := k8s.GetNodesE(t, kubectlOptions)
			if err != nil {
				return "", err
			}
			if len(nodes) != numNodes {
				return "", fmt.Errorf("Not enough nodes")
			}
			return "All nodes registered", nil
		},
	)
	if err != nil {
		logger.Logf(t, "Error waiting for expected number of nodes: %s", err)
		t.Fatal(err)
	}
	logger.Logf(t, message)
}
