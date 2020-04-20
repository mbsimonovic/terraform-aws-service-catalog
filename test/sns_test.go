package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestSnsTopics(t *testing.T) {
	t.Parallel()

	awsRegion := aws.GetRandomRegion(t, regionsForEc2Tests, nil)

	testFolder := "../examples/for-learning-and-testing/networking/sns-topics"
	terraformOptions := createBaseTerraformOptions(t, testFolder, awsRegion)
	terraformOptions.Vars["name"] = "test-topic-" + random.UniqueId()

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	topicArn := terraform.Output(t, terraformOptions, "topic_arn")
	assert.Regexp(t, "^arn:aws:sns:.*:test-topic-.*", topicArn)

}
