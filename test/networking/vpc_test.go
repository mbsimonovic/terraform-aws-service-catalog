package networking

import (
	"crypto/tls"
	"path/filepath"
	"testing"
	"time"

	"github.com/gruntwork-io/aws-service-catalog/test"

	"github.com/gruntwork-io/terratest/modules/aws"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVpc(t *testing.T) {
	t.Parallel()

	awsRegion := aws.GetRandomRegion(t, test.RegionsForEc2Tests, nil)
	port := 80

	testFolder := "../../examples/for-learning-and-testing/networking/vpc"
	terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
	terraformOptions.Vars["vpc_name"] = "vpc-test-" + random.UniqueId()
	terraformOptions.Vars["cidr_block"] = "10.100.0.0/18"
	terraformOptions.Vars["num_nat_gateways"] = "1"
	terraformOptions.Vars["sg_ingress_port"] = port

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	assert.Regexp(t, "^vpc-.*", vpcID)

	publicSubnetIDs := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.Regexp(t, "^subnet-.*", publicSubnetIDs[0])

	instanceURL := "http://" + terraform.Output(t, terraformOptions, "instance_ip")
	tlsConfig := tls.Config{}
	instanceText := "Hello, World"
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second
	http_helper.HttpGetWithRetry(t, instanceURL, &tlsConfig, 200, instanceText, maxRetries, timeBetweenRetries)
}

func TestVpcPeering(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_vpc_mgmt", "true")
	//os.Setenv("SKIP_deploy_vpc_app", "true")
	//os.Setenv("SKIP_destroy_vpc_app", "true")
	//os.Setenv("SKIP_destroy_vpc_mgmt", "true")

	// Create a directory path that won't conflict
	workingDir := filepath.Join(".", "stages", t.Name())

	examplesRoot := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples")
	vpcMgmtModulePath := filepath.Join(examplesRoot, "for-learning-and-testing/networking/vpc-mgmt")
	vpcAppModulePath := filepath.Join(examplesRoot, "for-learning-and-testing/networking/vpc")

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomRegion(t, test.RegionsForEc2Tests, nil)
		test_structure.SaveString(t, workingDir, "awsRegion", awsRegion)

		uniqueID := random.UniqueId()
		test_structure.SaveString(t, workingDir, "uniqueID", uniqueID)
	})
	awsRegion := test_structure.LoadString(t, workingDir, "awsRegion")
	uniqueID := test_structure.LoadString(t, workingDir, "uniqueID")

	vpcMgmtTFOptions := test.CreateBaseTerraformOptions(t, vpcMgmtModulePath, awsRegion)
	vpcMgmtTFOptions.Vars["vpc_name"] = "scvpc-peering-test-mgmt-" + uniqueID

	defer test_structure.RunTestStage(t, "destroy_vpc_mgmt", func() {
		terraform.Destroy(t, vpcMgmtTFOptions)
	})
	test_structure.RunTestStage(t, "deploy_vpc_mgmt", func() {
		terraform.InitAndApply(t, vpcMgmtTFOptions)
	})

	mgmtVpcID := terraform.Output(t, vpcMgmtTFOptions, "vpc_id")
	mgmtVpcName := terraform.Output(t, vpcMgmtTFOptions, "vpc_name")
	mgmtVpcCidrBlock := terraform.Output(t, vpcMgmtTFOptions, "vpc_cidr_block")
	mgmtVpcRouteTableIDs := terraform.OutputList(t, vpcMgmtTFOptions, "route_table_ids")
	mgmtVpcPublicSubnetIDs := terraform.OutputList(t, vpcMgmtTFOptions, "public_subnet_ids")
	vpcAppTFOptions := test.CreateBaseTerraformOptions(t, vpcAppModulePath, awsRegion)
	vpcAppTFOptions.Vars["vpc_name"] = "scvpc-peering-test-app-" + uniqueID
	vpcAppTFOptions.Vars["cidr_block"] = "10.1.0.0/16"
	vpcAppTFOptions.Vars["create_peering_connection"] = true
	vpcAppTFOptions.Vars["create_flow_logs"] = false
	vpcAppTFOptions.Vars["origin_vpc_id"] = mgmtVpcID
	vpcAppTFOptions.Vars["origin_vpc_name"] = mgmtVpcName
	vpcAppTFOptions.Vars["origin_vpc_cidr_block"] = mgmtVpcCidrBlock
	vpcAppTFOptions.Vars["origin_vpc_route_table_ids"] = mgmtVpcRouteTableIDs
	vpcAppTFOptions.Vars["origin_vpc_public_subnet_ids"] = mgmtVpcPublicSubnetIDs

	defer test_structure.RunTestStage(t, "destroy_vpc_app", func() {
		terraform.Destroy(t, vpcAppTFOptions)
	})
	test_structure.RunTestStage(t, "deploy_vpc_app", func() {
		terraform.InitAndApply(t, vpcAppTFOptions)
	})
}
