package services

import (
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	awsgo "github.com/aws/aws-sdk-go/aws"
	"github.com/gruntwork-io/terratest/modules/aws"
	dns_helper "github.com/gruntwork-io/terratest/modules/dns-helper"
	"github.com/gruntwork-io/terratest/modules/docker"
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
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	"github.com/gruntwork-io/aws-service-catalog/test"
)

const (
	// renovate.json auto-update-variable: terraform-aws-eks
	terraformAWSEKSVersion = "v0.32.4"
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

const (
	// 1 worker + 2 fargate pods for coredns
	expectedEksNodeCountWithoutAuthMerger = 3
	// 1 worker + 2 fargate pods for coredns + 1 fargate pod for aws-auth-merger
	expectedEksNodeCountWithAuthMerger = 4
	// 2 fargate pods for coredns
	expectedEksNodeCountFargateOnly = 2
)

func TestEksCluster(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_build_ami", "true")
	//os.Setenv("SKIP_build_aws_auth_merger_image", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate_cluster", "true")
	//os.Setenv("SKIP_validate_core_services_optionality", "true")
	//os.Setenv("SKIP_deploy_core_services", "true")
	//os.Setenv("SKIP_validate_core_services_fargate", "true")
	//os.Setenv("SKIP_validate_external_dns", "true")
	//os.Setenv("SKIP_deploy_sampleapp", "true")
	//os.Setenv("SKIP_validate_sampleapp", "true")
	//os.Setenv("SKIP_cleanup_sampleapp", "true")
	//os.Setenv("SKIP_cleanup_core_services", "true")
	//os.Setenv("SKIP_cleanup", "true")
	//os.Setenv("SKIP_cleanup_aws_auth_merger_image", "true")
	//os.Setenv("SKIP_cleanup_keypair", "true")
	//os.Setenv("SKIP_cleanup_ami", "true")

	// Create a directory path that won't conflict
	workingDir := filepath.Join(".", "stages", t.Name())

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		amiId := test_structure.LoadArtifactID(t, workingDir)
		awsRegion := test_structure.LoadString(t, workingDir, "region")
		aws.DeleteAmiAndAllSnapshots(t, awsRegion, amiId)
	})

	defer test_structure.RunTestStage(t, "cleanup_ami", func() {
		awsKeyPair := test_structure.LoadEc2KeyPair(t, workingDir)
		aws.DeleteEC2KeyPair(t, awsKeyPair)
	})

	test_structure.RunTestStage(t, "build_ami", func() {
		buildWorkerAmi(t, workingDir)
	})

	// Group the following two test scenarios in a subtest so that the cleanup routines only run after both tests have
	// finished
	t.Run("group", func(t *testing.T) {
		t.Run("WithCoreServicesAndAuthMerger", func(t *testing.T) {
			t.Parallel()
			testEKSClusterWithCoreServicesAndAuthMerger(t, workingDir)
		})
		t.Run("WithoutAuthMerger", func(t *testing.T) {
			t.Parallel()
			testEKSClusterWithoutAuthMerger(t, workingDir)
		})
	})
}

// Regression test to make sure the subnet filtering works to allow deploying EKS clusters to us-east-1 with Fargate
// pods.
func TestEksClusterFargateUsEast1(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_validate_cluster", "true")
	//os.Setenv("SKIP_deploy_core_services", "true")
	//os.Setenv("SKIP_validate_external_dns", "true")
	//os.Setenv("SKIP_cleanup_core_services", "true")
	//os.Setenv("SKIP_cleanup", "true")

	// Create a directory path that won't conflict
	workingDir := filepath.Join(".", "stages", t.Name())

	examplesRoot := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples")
	eksClusterRoot := filepath.Join(examplesRoot, "for-learning-and-testing/services/eks-cluster")
	coreServicesRoot := filepath.Join(examplesRoot, "for-learning-and-testing/services/eks-core-services")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		terraform.Destroy(t, terraformOptions)

		kubectlOptions := test_structure.LoadKubectlOptions(t, workingDir)
		os.Remove(kubectlOptions.ConfigPath)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		test_structure.SaveString(t, workingDir, "region", "us-east-1")
		deployEKSCluster(t, workingDir, workingDir, eksClusterRoot, false, true)
	})

	test_structure.RunTestStage(t, "validate_cluster", func() {
		validateEKSCluster(t, workingDir, expectedEksNodeCountFargateOnly)
	})

	defer test_structure.RunTestStage(t, "cleanup_core_services", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, coreServicesRoot)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_core_services", func() {
		coreServicesTerraformOptions := getCoreServicesTerraformOptions(t, workingDir, workingDir, coreServicesRoot)
		terraform.InitAndApply(t, coreServicesTerraformOptions)
	})

	test_structure.RunTestStage(t, "validate_core_services_fargate", func() {
		validateCoreServicesOnFargate(t, workingDir)
	})
}

// Test the eks-cluster module without deploying the aws-auth-merger. This test only checks if the requisite number of
// workers come up, as it is not necessary to redundantly test the core services and k8s-service modules that are tested
// in the path with aws-auth-merger.
func testEKSClusterWithoutAuthMerger(t *testing.T, parentWorkingDir string) {
	// Create a directory path that won't conflict. Note that this would be the full path to the subtest, unlike the
	// workingDir set in TestEksCluster (passed in as parentWorkingDir).
	workingDir := filepath.Join(".", "stages", t.Name())

	examplesRoot := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples")
	eksClusterRoot := filepath.Join(examplesRoot, "for-learning-and-testing/services/eks-cluster")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		terraform.Destroy(t, terraformOptions)

		kubectlOptions := test_structure.LoadKubectlOptions(t, workingDir)
		os.Remove(kubectlOptions.ConfigPath)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		deployEKSCluster(t, parentWorkingDir, workingDir, eksClusterRoot, false, false)
	})

	test_structure.RunTestStage(t, "validate_cluster", func() {
		validateEKSCluster(t, workingDir, expectedEksNodeCountWithoutAuthMerger)
	})
}

func testEKSClusterWithCoreServicesAndAuthMerger(t *testing.T, parentWorkingDir string) {
	// Create a directory path that won't conflict. Note that this would be the full path to the subtest, unlike the
	// workingDir set in TestEksCluster (passed in as parentWorkingDir).
	workingDir := filepath.Join(".", "stages", t.Name())

	examplesRoot := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples")
	eksClusterRoot := filepath.Join(examplesRoot, "for-learning-and-testing/services/eks-cluster")
	coreServicesRoot := filepath.Join(examplesRoot, "for-learning-and-testing/services/eks-core-services")
	k8sServiceRoot := filepath.Join(examplesRoot, "for-learning-and-testing/services/k8s-service")

	defer test_structure.RunTestStage(t, "cleanup_aws_auth_merger_image", func() {
		region := test_structure.LoadString(t, parentWorkingDir, "region")
		repository := test_structure.LoadString(t, workingDir, "ecrRepoName")
		aws.DeleteECRRepo(t, region, aws.GetECRRepo(t, region, repository))
	})
	test_structure.RunTestStage(t, "build_aws_auth_merger_image", func() {
		buildAWSAuthMergerImage(t, parentWorkingDir, workingDir)
	})

	defer test_structure.RunTestStage(t, "cleanup", func() {
		kubectlOptions := test_structure.LoadKubectlOptions(t, workingDir)
		os.Remove(kubectlOptions.ConfigPath)

		terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		deployEKSCluster(t, parentWorkingDir, workingDir, eksClusterRoot, true, false)
	})

	test_structure.RunTestStage(t, "validate_cluster", func() {
		validateEKSCluster(t, workingDir, expectedEksNodeCountWithAuthMerger)
	})

	defer test_structure.RunTestStage(t, "cleanup_core_services", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, coreServicesRoot)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "validate_core_services_optionality", func() {
		coreServicesTerraformOptions := getCoreServicesTerraformOptions(t, parentWorkingDir, workingDir, coreServicesRoot)

		// Set up vars to disable all the core services and verify nothing gets deployed.
		coreServicesTerraformOptions.Vars["enable_fluent_bit"] = false
		coreServicesTerraformOptions.Vars["enable_alb_ingress_controller"] = false
		coreServicesTerraformOptions.Vars["enable_external_dns"] = false
		coreServicesTerraformOptions.Vars["enable_cluster_autoscaler"] = false
		coreServicesTerraformOptions.Vars["service_dns_mappings"] = map[string]interface{}{}
		planCounts := terraform.GetResourceCount(t, terraform.InitAndPlan(t, coreServicesTerraformOptions))
		assert.Equal(t, 0, planCounts.Add)
		assert.Equal(t, 0, planCounts.Change)
		assert.Equal(t, 0, planCounts.Destroy)
	})
	coreServicesTerraformOptions := test_structure.LoadTerraformOptions(t, coreServicesRoot)

	test_structure.RunTestStage(t, "deploy_core_services", func() {
		terraform.InitAndApply(t, coreServicesTerraformOptions)
	})

	test_structure.RunTestStage(t, "validate_core_services_fargate", func() {
		validateCoreServicesOnFargate(t, workingDir)
	})

	test_structure.RunTestStage(t, "validate_external_dns", func() {
		validateExternalDNS(t, workingDir)
	})

	defer test_structure.RunTestStage(t, "cleanup_sampleapp", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, k8sServiceRoot)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "deploy_sampleapp", func() {
		deploySampleApp(t, parentWorkingDir, workingDir, k8sServiceRoot)
	})

	test_structure.RunTestStage(t, "validate_sampleapp", func() {
		validateSampleApp(t, workingDir, k8sServiceRoot)
	})

}

func buildWorkerAmi(t *testing.T, testFolder string) {
	awsRegion := aws.GetRandomStableRegion(t, eksFargateRegions, nil)
	test_structure.SaveString(t, testFolder, "region", awsRegion)

	branchName := git.GetCurrentBranchName(t)
	packerOptions := &packer.Options{
		Template: "../../modules/services/eks-cluster/eks-node-al2.json",
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
	test_structure.SaveArtifactID(t, testFolder, amiId)

	uniqueID := random.UniqueId()
	test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)

	awsKeyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueID)
	test_structure.SaveEc2KeyPair(t, testFolder, awsKeyPair)
}

// Deploy the EKS cluster module in the test.
// parentWorkingDir should be the working dir of the overarching test, and is where the global options like region and
// AMI are stored.
// workingDir should be the working dir of the subtest, and is where local options like the terraform options are
// stored.
func deployEKSCluster(
	t *testing.T,
	parentWorkingDir string,
	workingDir string,
	modulePath string,
	enableAWSAuthMerger bool,
	fargateOnly bool,
) {
	branchName := git.GetCurrentBranchName(t)
	awsRegion := test_structure.LoadString(t, parentWorkingDir, "region")

	clusterName := fmt.Sprintf("eks-service-catalog-%s", strings.ToLower(random.UniqueId()))
	test_structure.SaveString(t, workingDir, "clusterName", clusterName)

	terraformOptions := test.CreateBaseTerraformOptions(t, modulePath, awsRegion)
	terraformOptions.Vars["cluster_name"] = clusterName
	terraformOptions.Vars["cluster_instance_ami_version_tag"] = branchName

	// Pull in ECR image info and configure the vars to enable the aws-auth-merger if requested.
	if enableAWSAuthMerger {
		ecrRepoURI := test_structure.LoadString(t, workingDir, "ecrRepoURI")
		terraformOptions.Vars["enable_aws_auth_merger"] = true
		terraformOptions.Vars["aws_auth_merger_image"] = map[string]string{
			"repo": ecrRepoURI,
			"tag":  "v1",
		}
	}

	if fargateOnly {
		terraformOptions.Vars["fargate_only"] = true
	} else {
		awsKeyPair := test_structure.LoadEc2KeyPair(t, parentWorkingDir)
		terraformOptions.Vars["keypair_name"] = awsKeyPair.Name
	}

	test_structure.SaveTerraformOptions(t, workingDir, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}

// Validate the deployed EKS cluster has the requisite number of workers.
// workingDir should be the working dir of the subtest, and is where local options like the terraform options are
// stored.
func validateEKSCluster(t *testing.T, workingDir string, expectedEksNodeCount int) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	eksClusterArn := terraform.OutputRequired(t, terraformOptions, "eks_cluster_arn")

	tmpKubeConfigPath := configureKubectlForEKSCluster(t, eksClusterArn)
	kubectlOptions := k8s.NewKubectlOptions("", tmpKubeConfigPath, "")
	test_structure.SaveKubectlOptions(t, workingDir, kubectlOptions)

	kubeWaitUntilNumNodes(t, kubectlOptions, expectedEksNodeCount, 30, 10*time.Second)
	k8s.WaitUntilAllNodesReady(t, kubectlOptions, 30, 10*time.Second)
	readyNodes := k8s.GetReadyNodes(t, kubectlOptions)
	assert.Equal(t, len(readyNodes), expectedEksNodeCount)
}

// Setup the core services module terraform options in the test.
// parentWorkingDir should be the working dir of the overarching test, and is where the global options like region and
// AMI are stored.
// workingDir should be the working dir of the subtest, and is where local options like the terraform options are
// stored.
func getCoreServicesTerraformOptions(t *testing.T, parentWorkingDir string, workingDir string, coreServicesModulePath string) *terraform.Options {
	awsRegion := test_structure.LoadString(t, parentWorkingDir, "region")
	clusterName := test_structure.LoadString(t, workingDir, "clusterName")
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)

	eksClusterIRSAConfig := terraform.OutputMap(t, terraformOptions, "eks_iam_role_for_service_accounts_config")
	eksClusterVpcID := terraform.Output(t, terraformOptions, "eks_cluster_vpc_id")
	eksPrivateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")
	eksClusterFargateRole := terraform.Output(t, terraformOptions, "eks_default_fargate_execution_role_arn")

	coreServicesOptions := test.CreateBaseTerraformOptions(t, coreServicesModulePath, awsRegion)
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
	test_structure.SaveTerraformOptions(t, coreServicesModulePath, coreServicesOptions)

	return coreServicesOptions
}

// Validate the core services module is running on Fargate.
// parentWorkingDir should be the working dir of the overarching test, and is where the global options like region and
// AMI are stored.
// workingDir should be the working dir of the subtest, and is where local options like the terraform options are
// stored.
func validateCoreServicesOnFargate(t *testing.T, workingDir string) {
	kubectlOptions := test_structure.LoadKubectlOptions(t, workingDir)
	kubectlOptions.Namespace = "kube-system"

	ingressControllerLabelSelector := "app.kubernetes.io/instance=aws-alb-ingress-controller,app.kubernetes.io/name=aws-load-balancer-controller"
	assertFargate(t, kubectlOptions, ingressControllerLabelSelector)

	clusterAutoscalerLabelSelector := "app.kubernetes.io/instance=cluster-autoscaler,app.kubernetes.io/name=aws-cluster-autoscaler-chart"
	assertFargate(t, kubectlOptions, clusterAutoscalerLabelSelector)

	externalDNSLabelSelector := "app.kubernetes.io/instance=external-dns,app.kubernetes.io/name=external-dns"
	assertFargate(t, kubectlOptions, externalDNSLabelSelector)
}

func assertFargate(t *testing.T, kubectlOptions *k8s.KubectlOptions, labelSelectorStr string) {
	pods := k8s.ListPods(t, kubectlOptions, metav1.ListOptions{LabelSelector: labelSelectorStr})
	require.Greater(t, len(pods), 0)
	for _, pod := range pods {
		_, hasFargateLabel := pod.ObjectMeta.Labels["eks.amazonaws.com/fargate-profile"]
		assert.Truef(t, hasFargateLabel, "%s pod does not have fargate label", pod.ObjectMeta.Name)
	}
}

// Validate the deployed external-dns service is running and healthy by using a investigation pod.
// workingDir should be the working dir of the subtest, and is where local options like the terraform options are
// stored.
func validateExternalDNS(t *testing.T, workingDir string) {
	kubectlOptions := test_structure.LoadKubectlOptions(t, workingDir)

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

// Deploy the Gruntwork AWS Sample App using the k8s-service module in to the test cluster.
// parentWorkingDir should be the working dir of the overarching test, and is where the global options like region and
// AMI are stored.
// workingDir should be the working dir of the subtest, and is where local options like the terraform options are
// stored.
func deploySampleApp(t *testing.T, parentWorkingDir string, workingDir string, k8sServiceModulePath string) {
	uniqueID := test_structure.LoadString(t, parentWorkingDir, "uniqueID")
	awsRegion := test_structure.LoadString(t, parentWorkingDir, "region")
	clusterName := test_structure.LoadString(t, workingDir, "clusterName")
	applicationName := fmt.Sprintf("sampleapp-%s", strings.ToLower(uniqueID))
	test_structure.SaveString(t, k8sServiceModulePath, "applicationName", applicationName)

	k8sServiceOptions := test.CreateBaseTerraformOptions(t, k8sServiceModulePath, awsRegion)
	k8sServiceOptions.Vars["application_name"] = applicationName
	k8sServiceOptions.Vars["expose_type"] = "external"
	k8sServiceOptions.Vars["domain_name"] = fmt.Sprintf("sample-app-%s.%s", clusterName, test.BaseDomainForTest)
	k8sServiceOptions.Vars["aws_region"] = awsRegion
	k8sServiceOptions.Vars["kubeconfig_auth_type"] = "eks"
	k8sServiceOptions.Vars["kubeconfig_eks_cluster_name"] = clusterName
	test_structure.SaveTerraformOptions(t, k8sServiceModulePath, k8sServiceOptions)

	terraform.InitAndApply(t, k8sServiceOptions)
}

// Validate the deployed sample app service came up correctly.
// workingDir should be the working dir of the subtest, and is where local options like the terraform options are
// stored.
func validateSampleApp(t *testing.T, workingDir string, k8sServiceModulePath string) {
	terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)
	clusterName := test_structure.LoadString(t, workingDir, "clusterName")
	eksClusterArn := terraform.OutputRequired(t, terraformOptions, "eks_cluster_arn")
	applicationName := test_structure.LoadString(t, k8sServiceModulePath, "applicationName")

	tmpKubeConfigPath := configureKubectlForEKSCluster(t, eksClusterArn)
	defer os.Remove(tmpKubeConfigPath)
	options := k8s.NewKubectlOptions("", tmpKubeConfigPath, "default")

	sampleAppValidationFunction := sampleAppValidationWithGreetingFunctionGenerator("Hello from the dev config!")

	verifyPodsCreatedSuccessfully(t, options, applicationName)
	verifyAllPodsAvailable(t, options, applicationName, "/greeting", sampleAppValidationFunction)

	// Wait until the DNS entry is resolvable before attempting to get the address. This ensures that we wait for the
	// hostname to have propagated through DNS before making requests to it. Otherwise, if we make requests too early,
	// before DNS has propagated, the missing DNS entry gets recorded in the local cache, and the test will keep
	// failing, despite retries.
	hostname := fmt.Sprintf("sample-app-%s.%s", clusterName, test.BaseDomainForTest)
	dns_helper.DNSLookupAuthoritativeWithRetry(
		t,
		dns_helper.DNSQuery{
			Type: "A",
			Name: hostname,
		},
		nil,
		K8SServiceWaitTimerRetries,
		K8SIngressWaitTimerSleep,
	)

	ingressEndpoint := fmt.Sprintf("https://%s/greeting", hostname)
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

// Build the aws-auth-merger Docker image using the terraform-aws-eks repo.
// parentWorkingDir should be the working dir of the overarching test, and is where the global options like region and
// AMI are stored.
// workingDir should be the working dir of the subtest, and is where local options like the terraform options are
// stored.
func buildAWSAuthMergerImage(t *testing.T, parentWorkingDir string, workingDir string) {
	uniqueID := test_structure.LoadString(t, parentWorkingDir, "uniqueID")
	region := test_structure.LoadString(t, parentWorkingDir, "region")

	// Setup the ECR repo for the aws-auth-merger
	repositoryName := fmt.Sprintf("gruntwork/aws-auth-merger-%s", strings.ToLower(uniqueID))
	test_structure.SaveString(t, workingDir, "ecrRepoName", repositoryName)

	repository := aws.CreateECRRepo(t, region, repositoryName)
	repositoryURI := awsgo.StringValue(repository.RepositoryUri)
	test_structure.SaveString(t, workingDir, "ecrRepoURI", repositoryURI)

	tmpDir, err := ioutil.TempDir("", "")
	require.NoError(t, err)
	// We remove the temp dir at the end of this routine because we don't need it once the docker image is built
	defer os.RemoveAll(tmpDir)
	repoDir := filepath.Join(tmpDir, "terraform-aws-eks")

	// Build and push the aws-auth-merger docker image. We need to clone terraform-aws-eks first so we have access
	// to the Dockerfile
	cloneCmd := shell.Command{
		Command: "git",
		Args: []string{
			"clone",
			"git@github.com:gruntwork-io/terraform-aws-eks.git",
			repoDir,
		},
	}
	shell.RunCommand(t, cloneCmd)
	checkoutCmd := shell.Command{
		Command:    "git",
		Args:       []string{"checkout", terraformAWSEKSVersion},
		WorkingDir: repoDir,
	}
	shell.RunCommand(t, checkoutCmd)

	awsAuthMergerDockerRepoTag := fmt.Sprintf("%s:v1", repositoryURI)
	buildOpts := &docker.BuildOptions{
		Tags:         []string{awsAuthMergerDockerRepoTag},
		OtherOptions: []string{"--no-cache"},
	}
	docker.Build(t, filepath.Join(repoDir, "modules/eks-aws-auth-merger"), buildOpts)
	test.RunCommandWithEcrAuth(t, fmt.Sprintf("docker push %s", awsAuthMergerDockerRepoTag), region)
}
