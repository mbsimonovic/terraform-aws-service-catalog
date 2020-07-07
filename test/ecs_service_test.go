package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
)

func TestEcsService(t *testing.T) {
	t.Parallel()

	testFolder := "../examples/for-learning-and-testing/services/ecs-service"

	uniqueID := random.UniqueId()
	serviceName := fmt.Sprintf("nginx-%s", strings.ToLower(uniqueID))
	terraformOptions := createBaseTerraformOptions(t, testFolder, "us-west-2")
	terraformOptions.Vars["service_name"] = serviceName
	terraformOptions.Vars["ecs_cluster_arn"] = "TODO"
}
