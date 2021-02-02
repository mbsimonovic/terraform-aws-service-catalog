package networking

import (
	"crypto/tls"
	"testing"
	"time"

	"github.com/gruntwork-io/aws-service-catalog/test"

	"github.com/gruntwork-io/terratest/modules/aws"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVpcMgmt(t *testing.T) {
	t.Parallel()

	awsRegion := aws.GetRandomRegion(t, test.RegionsForEc2Tests, nil)
	port := 80

	testFolder := "../../examples/for-learning-and-testing/networking/vpc-mgmt"
	terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
	terraformOptions.Vars["vpc_name"] = "vpc-mgmt-test-" + random.UniqueId()
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
