package test

import (
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	testcommon "github.com/gruntwork-io/aws-service-catalog/test/common"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

// This is the Org Test Account
const AWSAccountId = "966198709205"

func TestAccountBaselines(t *testing.T) {
	t.Parallel()

	var testCases = []struct {
		testName   string
		exampleDir string
		isOrg      bool
		createOrg  bool
		isApp      bool
	}{
		{
			"TestRootExistingOrgPlan",
			"account-baseline-root",
			true,
			false,
			false,
		},
		/*{
			"TestRootNewOrgPlan",
			"account-baseline-root",
			true,
			true,
			false,
		},
		{
			"TestSecurityPlan",
			"account-baseline-security",
			false,
			false,
			false,
		},
		{
			"TestAppPlan",
			"account-baseline-app",
			false,
			false,
			true,
		},*/
	}

	for _, testCase := range testCases {
		// The following is necessary to make sure testCase's values don't
		// get updated due to concurrency within the scope of t.Run(..) below
		testCase := testCase

		t.Run(testCase.testName, func(t *testing.T) {
			t.Parallel()

			//os.Setenv("SKIP_bootstrap", "true")
			//os.Setenv("SKIP_plan_and_verify", "true")

			workingDir := filepath.Join("../examples/for-learning-and-testing/landingzone", testCase.exampleDir)

			test_structure.RunTestStage(t, "bootstrap", func() {
				logger.Logf(t, "Bootstrapping variables")

				awsRegion := testcommon.PickAwsRegion(t)

				terraformOptions := testcommon.CreateBaseTerraformOptions(t, workingDir, awsRegion)

				if testCase.isOrg {
					terraformOptions.Vars["create_organization"] = testCase.createOrg
				}
				terraformOptions.Vars["aws_account_id"] = AWSAccountId
				terraformOptions.Vars["name_prefix"] = strings.ToLower(testCase.exampleDir)

				if testCase.isApp {
					terraformOptions.Vars["allow_auto_deploy_from_other_account_arns"] = []string{"arn:aws:iam::123445678910:role/jenkins"}
					terraformOptions.Vars["allow_read_only_access_from_other_account_arns"] = []string{"arn:aws:iam::123445678910:root"}
					terraformOptions.Vars["auto_deploy_permissions"] = []string{"cloudwatch:*", "logs:*", "dynamodb:*", "ecr:*", "ecs:*"}
					terraformOptions.Vars["dev_permitted_services"] = []string{"ec2", "s3", "rds", "dynamodb", "elasticache"}
				}

				test_structure.SaveTerraformOptions(t, workingDir, terraformOptions)
			})

			test_structure.RunTestStage(t, "plan_and_verify", func() {
				logger.Log(t, "Running terraform plan")

				terraformOptions := test_structure.LoadTerraformOptions(t, workingDir)

				// We're testing against a separate account and need to connect to root account
				// Just storing the env vars in the in-memory map
				configureTerraformForOrgTestAccount(t, terraformOptions)

				// NOTE: Do *NOT* run apply for this test because destroy will not delete the child account,
				// so eventually we'd be left with hundreds of unusable accounts
				result, err := terraform.InitAndPlanE(t, terraformOptions)

				assert.NoError(t, err, "Should not get plan error")

				// Main purpose of the test is to verify that plan executes successfully, so we catch configuration
				// issues in the test run. As the amount of resources to be created is close to 200, it makes no
				// sense to do regexps for each of those.
				// Once terratest is upgraded to 0.12 compat, we can make use of structured output, which makes the
				// assertions much more manageable. At that point it might make sense to do a more thorough examination
				// of the outputs.
				if testCase.isOrg {
					assert.Regexp(t, regexp.MustCompile(`child_accounts\["acme-example-security"\].*will be created`), result, "Should create acme-example-security account")
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
