package test

import (
	"fmt"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestAccountBaselines(t *testing.T) {
	t.Parallel()

	requireEnvVar(t, "TEST_EXTERNAL_ACCOUNT_ID")
	awsAccountID := getExternalAccountId()

	var testCases = []struct {
		testName   string
		exampleDir string
		isOrg      bool
		createOrg  bool
		isApp      bool
		isLogs     bool
		isSecurity bool
	}{
		{
			"TestRootExistingOrgPlan",
			"account-baseline-root",
			true,
			false,
			false,
			false,
			false,
		},
		{
			"TestRootNewOrgPlan",
			"account-baseline-root",
			true,
			true,
			false,
			false,
			false,
		},
		{
			"TestSecurityPlan",
			"account-baseline-security",
			false,
			false,
			false,
			false,
			true,
		},
		{
			"TestLogsPlan",
			"account-baseline-app",
			false,
			false,
			false,
			true,
			false,
		},
		{
			"TestAppPlan",
			"account-baseline-app",
			false,
			false,
			true,
			false,
			false,
		},
	}

	for _, testCase := range testCases {
		// The following is necessary to make sure testCase's values don't
		// get updated due to concurrency within the scope of t.Run(..) below
		testCase := testCase

		t.Run(testCase.testName, func(t *testing.T) {
			t.Parallel()

			//os.Setenv("SKIP_bootstrap", "true")
			//os.Setenv("SKIP_plan_and_verify", "true")

			_examplesDir := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/for-learning-and-testing/landingzone")
			exampleDir := filepath.Join(_examplesDir, testCase.exampleDir)

			childAccounts := map[string]interface{}{
				"logs": map[string]interface{}{
					"email":           "root-accounts+logs@acme.com",
					"is_logs_account": true,
				},
				"security": map[string]interface{}{
					"email":                      "root-accounts+security@acme.com",
					"role_name":                  "OrganizationAccountAccessRole",
					"iam_user_access_to_billing": "DENY",
				},
				"dev": map[string]interface{}{
					"email": "root-accounts+dev@acme.com",
				},
			}

			test_structure.RunTestStage(t, "bootstrap", func() {
				logger.Logf(t, "Bootstrapping variables")

				awsRegion := pickAwsRegion(t)

				terraformOptions := createBaseTerraformOptions(t, exampleDir, awsRegion)

				if testCase.isOrg {
					terraformOptions.Vars["create_organization"] = testCase.createOrg
					terraformOptions.Vars["child_accounts"] = childAccounts
				}
				terraformOptions.Vars["aws_account_id"] = awsAccountID
				terraformOptions.Vars["name_prefix"] = strings.ToLower(testCase.testName)

				// Test using the account-baseline-app example for the purposes of deploying the logs account
				if testCase.isLogs {
					terraformOptions.Vars["config_s3_bucket_name"] = "gruntwork-lz-config-bucket"
					terraformOptions.Vars["config_aggregate_config_data_in_external_account"] = false
					terraformOptions.Vars["config_central_account_id"] = "123445678910"
					terraformOptions.Vars["cloudtrail_s3_bucket_name"] = "gruntwork-lz-cloudtrail-bucket"
					terraformOptions.Vars["cloudtrail_kms_key_arn"] = "arn:aws:kms:us-east-1:123445678910:key/12345678-1234-123a-b456-78889123456e3"
					terraformOptions.Vars["allow_full_access_from_other_account_arns"] = []string{"arn:aws:iam::123445678910:root"}
				}

				// Simulate deploying the security account after the logs account exists
				if testCase.isSecurity {
					terraformOptions.Vars["config_s3_bucket_name"] = "gruntwork-lz-config-bucket"
					terraformOptions.Vars["config_central_account_id"] = "123445678910"
					terraformOptions.Vars["cloudtrail_s3_bucket_name"] = "gruntwork-lz-cloudtrail-bucket"
					terraformOptions.Vars["cloudtrail_kms_key_arn"] = "arn:aws:kms:us-east-1:123445678910:key/12345678-1234-123a-b456-78889123456e3"
				}

				// Simulate deploying the app account after the logs account exists
				if testCase.isApp {
					terraformOptions.Vars["config_s3_bucket_name"] = "gruntwork-lz-config-bucket"
					terraformOptions.Vars["config_central_account_id"] = "123445678910"
					terraformOptions.Vars["config_aggregate_config_data_in_external_account"] = true
					terraformOptions.Vars["cloudtrail_s3_bucket_name"] = "gruntwork-lz-cloudtrail-bucket"
					terraformOptions.Vars["cloudtrail_kms_key_arn"] = "arn:aws:kms:us-east-1:123445678910:key/12345678-1234-123a-b456-78889123456e3"
					terraformOptions.Vars["allow_auto_deploy_from_other_account_arns"] = []string{"arn:aws:iam::123445678910:role/jenkins"}
					terraformOptions.Vars["allow_read_only_access_from_other_account_arns"] = []string{"arn:aws:iam::123445678910:root"}
					terraformOptions.Vars["auto_deploy_permissions"] = []string{"cloudwatch:*", "logs:*", "dynamodb:*", "ecr:*", "ecs:*"}
					terraformOptions.Vars["dev_permitted_services"] = []string{"ec2", "s3", "rds", "dynamodb", "elasticache"}
				}

				test_structure.SaveTerraformOptions(t, exampleDir, terraformOptions)
			})

			test_structure.RunTestStage(t, "plan_and_verify", func() {
				logger.Log(t, "Running terraform plan")

				terraformOptions := test_structure.LoadTerraformOptions(t, exampleDir)

				// We're testing against a separate account and need to connect to root account
				// Just storing the env vars in the in-memory map
				configureTerraformForOrgTestAccount(t, terraformOptions)

				// NOTE: Do *NOT* run apply for this test because destroy will not delete the child account,
				// so eventually we'd be left with hundreds of unusable accounts. We also pass `-parallelism=2`
				// to the terraform plan command as we've found the default value of 20 causes instability and
				// eventual consistency issues when using the landing zone modules.
				_, err := terraform.InitE(t, terraformOptions)
				require.NoError(t, err, "Should not get init error")

				result, err := planWithParallelismE(t, terraformOptions)

				assert.NoError(t, err, "Should not get plan error")

				// Main purpose of the test is to verify that plan executes successfully, so we catch configuration
				// issues in the test run. As the amount of resources to be created is close to 200, it makes no
				// sense to do regexps for each of those.
				// Once terratest is upgraded to 0.12 compat, we can make use of structured output, which makes the
				// assertions much more manageable. At that point it might make sense to do a more thorough examination
				// of the outputs.
				if testCase.isOrg {
					for accountName, _ := range childAccounts {
						accountWillBeCreatedRegexp, err := regexp.Compile(fmt.Sprintf(`child_accounts\["%s"\].*will be created`, accountName))
						require.NoError(t, err)
						assert.Regexp(t, accountWillBeCreatedRegexp, result)
					}
				}

				assert.Regexp(t, regexp.MustCompile(`aws_guardduty_detector.guardduty\[0\].*will be created`), result, "Should create guardduty")

				if testCase.isApp {
					assert.Contains(t, result, "jenkins", "Must contain `jenkins` for auto deploy from other accounts")
					assert.Contains(t, result, "arn:aws:iam::123445678910:root", "Must contain account arn for ro access from other accounts")
				}
			})
		})
	}
}
