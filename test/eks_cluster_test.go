package test

import (
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/git"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
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

// See https://docs.aws.amazon.com/eks/latest/userguide/fargate.html for list
var eksFargateRegions = []string{
	"us-east-2",
	"eu-west-1",
	"ap-northeast-1",
}

// 1 worker + 2 fargate pods
const expectedEksNodeCount = 3

func TestEksCluster(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_build_ami", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate_cluster", "true")
	//os.Setenv("SKIP_deploy_core_services", "true")
	//os.Setenv("SKIP_validate_external_dns", "true")
	//os.Setenv("SKIP_deploy_sampleapp", "true")
	//os.Setenv("SKIP_validate_sampleapp", "true")
	//os.Setenv("SKIP_cleanup_sampleapp", "true")
	//os.Setenv("SKIP_cleanup_core_services", "true")
	//os.Setenv("SKIP_cleanup", "true")
	//os.Setenv("SKIP_cleanup_keypair", "true")
	//os.Setenv("SKIP_cleanup_ami", "true")

	testFolder := "../examples/for-learning-and-testing/services/eks-cluster"
	coreServicesTestFolder := "../examples/for-learning-and-testing/services/eks-core-services"
	k8sServiceTestFolder := "../examples/for-learning-and-testing/services/k8s-service"

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
		kubectlOptions := test_structure.LoadKubectlOptions(t, testFolder)
		os.Remove(kubectlOptions.ConfigPath)

		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		buildWorkerAmi(t, testFolder)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		deployEKSCluster(t, testFolder)
	})

	test_structure.RunTestStage(t, "validate_cluster", func() {
		validateEKSCluster(t, testFolder)
	})

	defer test_structure.RunTestStage(t, "cleanup_core_services", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, coreServicesTestFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_core_services", func() {
		deployCoreServices(t, testFolder, coreServicesTestFolder)
	})

	test_structure.RunTestStage(t, "validate_external_dns", func() {
		validateExternalDNS(t, testFolder)
	})

	defer test_structure.RunTestStage(t, "cleanup_sampleapp", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, k8sServiceTestFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_sampleapp", func() {
		deploySampleApp(t, testFolder, k8sServiceTestFolder)
	})

	test_structure.RunTestStage(t, "validate_sampleapp", func() {
		validateSampleApp(t, testFolder, k8sServiceTestFolder)
	})
}

func buildWorkerAmi(t *testing.T, testFolder string) {
	awsRegion := aws.GetRandomStableRegion(t, eksFargateRegions, nil)
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
	test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)

	clusterName := fmt.Sprintf("eks-service-catalog-%s", strings.ToLower(uniqueID))
	test_structure.SaveString(t, testFolder, "clusterName", clusterName)

	awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)
	test_structure.SaveEc2KeyPair(t, testFolder, awsKeyPair)
}

func deployEKSCluster(t *testing.T, testFolder string) {
	branchName := git.GetCurrentBranchName(t)
	awsRegion := test_structure.LoadString(t, testFolder, "region")
	clusterName := test_structure.LoadString(t, testFolder, "clusterName")
	awsKeyPair := test_structure.LoadEc2KeyPair(t, testFolder)

	terraformOptions := createBaseTerraformOptions(t, testFolder, awsRegion)
	terraformOptions.Vars["cluster_name"] = clusterName
	terraformOptions.Vars["cluster_instance_ami_version_tag"] = branchName
	terraformOptions.Vars["keypair_name"] = awsKeyPair.Name

	test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}

func validateEKSCluster(t *testing.T, testFolder string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
	eksClusterArn := terraform.OutputRequired(t, terraformOptions, "eks_cluster_arn")

	tmpKubeConfigPath := configureKubectlForEKSCluster(t, eksClusterArn)
	kubectlOptions := k8s.NewKubectlOptions("", tmpKubeConfigPath, "")
	test_structure.SaveKubectlOptions(t, testFolder, kubectlOptions)

	kubeWaitUntilNumNodes(t, kubectlOptions, expectedEksNodeCount, 30, 10*time.Second)
	k8s.WaitUntilAllNodesReady(t, kubectlOptions, 30, 10*time.Second)
	readyNodes := k8s.GetReadyNodes(t, kubectlOptions)
	assert.Equal(t, len(readyNodes), expectedEksNodeCount)
}

func deployCoreServices(t *testing.T, eksClusterTestFolder string, coreServicesTestFolder string) {
	awsRegion := test_structure.LoadString(t, eksClusterTestFolder, "region")
	clusterName := test_structure.LoadString(t, eksClusterTestFolder, "clusterName")
	terraformOptions := test_structure.LoadTerraformOptions(t, eksClusterTestFolder)

	eksClusterIRSAConfig := terraform.OutputMap(t, terraformOptions, "eks_iam_role_for_service_accounts_config")
	eksClusterVpcID := terraform.Output(t, terraformOptions, "eks_cluster_vpc_id")
	eksPrivateSubnetIDs := terraform.Output(t, terraformOptions, "private_subnet_ids")
	eksClusterFargateRole := terraform.Output(t, terraformOptions, "eks_default_fargate_execution_role_arn")

	coreServicesOptions := createBaseTerraformOptions(t, coreServicesTestFolder, awsRegion)
	coreServicesOptions.Vars["eks_cluster_name"] = clusterName
	coreServicesOptions.Vars["vpc_id"] = eksClusterVpcID
	coreServicesOptions.Vars["worker_vpc_subnet_ids"] = eksPrivateSubnetIDs
	coreServicesOptions.Vars["eks_iam_role_for_service_accounts_config"] = eksClusterIRSAConfig
	coreServicesOptions.Vars["external_dns_route53_hosted_zone_tag_filters"] = defaultDomainTagFilterForTest
	coreServicesOptions.Vars["pod_execution_iam_role_arn"] = eksClusterFargateRole
	coreServicesOptions.Vars["service_dns_mappings"] = map[string]interface{}{
		"whatismyip": map[string]interface{}{
			"target_dns":  "checkip.amazonaws.com",
			"target_port": 80,
			"namespace":   "default",
		},
	}
	test_structure.SaveTerraformOptions(t, coreServicesTestFolder, coreServicesOptions)

	terraform.InitAndApply(t, coreServicesOptions)
}

func validateExternalDNS(t *testing.T, testFolder string) {
	kubectlOptions := test_structure.LoadKubectlOptions(t, testFolder)

	namespaceName := strings.ToLower(random.UniqueId())

	defer k8s.DeleteNamespace(t, kubectlOptions, namespaceName)
	k8s.CreateNamespace(t, kubectlOptions, namespaceName)
	kubectlOptions.Namespace = namespaceName

	out, err := k8s.RunKubectlAndGetOutputE(
		t,
		kubectlOptions,
		"run",
		"--attach",
		"--quiet",
		"--rm",
		"--restart=Never",
		"curl",
		"--image",
		"curlimages/curl",
		"--",
		"-s",
		// We have to set the host to checkip.amazonaws.com in the header, because the endpoint only works if the Host
		// header is set to the server. Otherwise, it returns a generic landing page for the lighthttpd server.
		"-H", "Host: checkip.amazonaws.com",
		"whatismyip.default.svc.cluster.local",
	)
	require.NoError(t, err)

	// Output can sometimes contain an error message if kubectl attempts to connect to pod too early, so we always
	// get the last line of the output.
	outLines := strings.Split(out, "\n")
	maybeIP := outLines[len(outLines)-1]
	require.NotNil(t, net.ParseIP(maybeIP))
}

func deploySampleApp(t *testing.T, eksClusterTestFolder string, k8sServiceTestFolder string) {
	uniqueID := test_structure.LoadString(t, eksClusterTestFolder, "uniqueID")
	awsRegion := test_structure.LoadString(t, eksClusterTestFolder, "region")
	clusterName := test_structure.LoadString(t, eksClusterTestFolder, "clusterName")
	applicationName := fmt.Sprintf("sampleapp-%s", strings.ToLower(uniqueID))
	test_structure.SaveString(t, k8sServiceTestFolder, "applicationName", applicationName)

	k8sServiceOptions := createBaseTerraformOptions(t, k8sServiceTestFolder, awsRegion)
	k8sServiceOptions.Vars["application_name"] = applicationName
	k8sServiceOptions.Vars["expose_type"] = "external"
	k8sServiceOptions.Vars["domain_name"] = fmt.Sprintf("sample-app-%s.%s", clusterName, baseDomainForTest)
	k8sServiceOptions.Vars["aws_region"] = awsRegion
	k8sServiceOptions.Vars["kubeconfig_auth_type"] = "eks"
	k8sServiceOptions.Vars["kubeconfig_eks_cluster_name"] = clusterName
	test_structure.SaveTerraformOptions(t, k8sServiceTestFolder, k8sServiceOptions)

	terraform.InitAndApply(t, k8sServiceOptions)
}

func validateSampleApp(t *testing.T, eksClusterTestFolder string, k8sServiceTestFolder string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, eksClusterTestFolder)
	clusterName := test_structure.LoadString(t, eksClusterTestFolder, "clusterName")
	eksClusterArn := terraform.OutputRequired(t, terraformOptions, "eks_cluster_arn")
	applicationName := test_structure.LoadString(t, k8sServiceTestFolder, "applicationName")

	tmpKubeConfigPath := configureKubectlForEKSCluster(t, eksClusterArn)
	defer os.Remove(tmpKubeConfigPath)
	options := k8s.NewKubectlOptions("", tmpKubeConfigPath, "default")
	verifyPodsCreatedSuccessfully(t, options, applicationName)
	verifyAllPodsAvailable(t, options, applicationName, "/health", sampleAppValidationFunction)

	ingressEndpoint := fmt.Sprintf("https://sample-app-%s.%s/health", clusterName, baseDomainForTest)
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		ingressEndpoint,
		nil,
		K8SServiceWaitTimerRetries,
		K8SIngressWaitTimerSleep,
		sampleAppValidationFunction,
	)
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
