package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestEcsService(t *testing.T) {
	t.Parallel()

	testFolder := "../examples/for-learning-and-testing/services/ecs-service"

	uniqueID := random.UniqueId()
	serviceName := fmt.Sprintf("nginx-%s", strings.ToLower(uniqueID))
	portMappings := map[string]int{
		"22":  22,
		"80":  80,
		"443": 443,
	}

	terraformOptions := createBaseTerraformOptions(t, testFolder, "us-west-1")

	terraformOptions.Vars["service_name"] = serviceName
	terraformOptions.Vars["ecs_cluster_name"] = "ecs-service-catalog-crofa3"
	terraformOptions.Vars["ecs_cluster_arn"] = "arn:aws:ecs:us-west-1:087285199408:cluster/ecs-service-catalog-crofa3"

	// TODO: cleanup the following vars
	terraformOptions.Vars["aws_region"] = "us-west-1"
	terraformOptions.Vars["aws_account_id"] = "087285199408"
	terraformOptions.Vars["desired_number_of_tasks"] = 1
	terraformOptions.Vars["desired_number_of_canary_tasks"] = 0
	terraformOptions.Vars["min_number_of_tasks"] = 1
	terraformOptions.Vars["max_number_of_tasks"] = 3
	terraformOptions.Vars["image"] = "nginx"
	terraformOptions.Vars["image_version"] = "1.17"
	terraformOptions.Vars["canary_version"] = "1.2"
	terraformOptions.Vars["cpu"] = 2
	terraformOptions.Vars["memory"] = 500
	terraformOptions.Vars["vpc_env_var_name"] = "placeholder"
	terraformOptions.Vars["ecs_node_port_mappings"] = portMappings
	terraformOptions.Vars["high_cpu_utilization_threshold"] = 90
	terraformOptions.Vars["high_cpu_utilization_period"] = 300
	terraformOptions.Vars["high_memory_utilization_threshold"] = 90
	terraformOptions.Vars["high_memory_utilization_period"] = 300
	terraformOptions.Vars["alarm_sns_topic_arn"] = "TODO"
	terraformOptions.Vars["kms_master_key_arn"] = "TODO"
	terraformOptions.Vars["ecs_instance_security_group_id"] = "TODO"
	terraformOptions.Vars["db_primary_endpoint"] = "https://example.com"
	terraformOptions.Vars["use_custom_docker_run_command"] = false

	terraform.InitAndApply(t, terraformOptions)
}
