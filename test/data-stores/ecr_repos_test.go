package data_stores

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/aws-service-catalog/test"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/docker"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestEcrRepos(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_build_and_push_docker_image", "true")
	//os.Setenv("SKIP_validate_image", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples/for-learning-and-testing/data-stores/ecr-repos")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "setup", func() {
		awsRegion := aws.GetRandomStableRegion(t, nil, nil)
		test_structure.SaveString(t, testFolder, "region", awsRegion)

		uniqueID := strings.ToLower(random.UniqueId())
		test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")

		name := fmt.Sprintf("sample-app-%s", strings.ToLower(uniqueID))
		test_structure.SaveString(t, testFolder, "repoName", name)

		terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
		terraformOptions.Vars["repositories"] = map[string]interface{}{
			name: map[string]interface{}{
				"external_account_ids_with_read_access":  []string{},
				"external_account_ids_with_write_access": []string{},
				"tags":                                   map[string]string{"Organization": "Gruntwork"},
				"enable_automatic_image_scanning":        true,
			},
		}

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	validateECRRepo(t, testFolder)
}

func TestEcrReposWithEncryption(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	//os.Setenv("TERRATEST_REGION", "eu-west-1")
	//os.Setenv("SKIP_setup", "true")
	//os.Setenv("SKIP_deploy_terraform", "true")
	//os.Setenv("SKIP_build_and_push_docker_image", "true")
	//os.Setenv("SKIP_validate_image", "true")
	//os.Setenv("SKIP_cleanup", "true")

	testFolder := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples/for-learning-and-testing/data-stores/ecr-repos")

	defer test_structure.RunTestStage(t, "cleanup", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
		terraform.Destroy(t, terraformOptions)
	})

	test_structure.RunTestStage(t, "setup", func() {
		// We hard code to us-east-1 so that we can use the dedicated test KMS key.
		test_structure.SaveString(t, testFolder, "region", "us-east-1")

		uniqueID := strings.ToLower(random.UniqueId())
		test_structure.SaveString(t, testFolder, "uniqueID", uniqueID)
	})

	test_structure.RunTestStage(t, "deploy_terraform", func() {
		awsRegion := test_structure.LoadString(t, testFolder, "region")
		uniqueID := test_structure.LoadString(t, testFolder, "uniqueID")

		name := fmt.Sprintf("sample-app-%s", strings.ToLower(uniqueID))
		test_structure.SaveString(t, testFolder, "repoName", name)

		terraformOptions := test.CreateBaseTerraformOptions(t, testFolder, awsRegion)
		terraformOptions.Vars["repositories"] = map[string]interface{}{
			name: map[string]interface{}{
				"encryption_config": map[string]string{
					"encryption_type": "KMS",
					"kms_key":         "alias/dedicated-test-key",
				},
			},
		}

		test_structure.SaveTerraformOptions(t, testFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	validateECRRepo(t, testFolder)
}

// TODO: Once terratest has support for testing with plan files, update with plan testing for the various merge
// functionalities. In lieu of that, we do the more brittle count based tests here for now.

type IAMPoliciesTestCase struct {
	name                          string
	shouldCreate                  bool
	defaultReadAccessAccountIDs   []string
	defaultWriteAccessAccountIDs  []string
	overrideWriteAccessAccountIDs []string
	overrideReadAccessAccountIDs  []string
}

func TestEcrReposIAMPoliciesLogic(t *testing.T) {
	t.Parallel()

	testCases := []IAMPoliciesTestCase{
		IAMPoliciesTestCase{
			name:                          "test-all-empty",
			shouldCreate:                  false,
			overrideReadAccessAccountIDs:  nil,
			defaultReadAccessAccountIDs:   []string{},
			overrideWriteAccessAccountIDs: nil,
			defaultWriteAccessAccountIDs:  []string{},
		},
		IAMPoliciesTestCase{
			name:                          "test-override-read-access",
			shouldCreate:                  true,
			overrideReadAccessAccountIDs:  []string{"11111111"},
			defaultReadAccessAccountIDs:   []string{},
			overrideWriteAccessAccountIDs: nil,
			defaultWriteAccessAccountIDs:  []string{},
		},
		IAMPoliciesTestCase{
			name:                          "test-override-read-access-empty",
			shouldCreate:                  false,
			overrideReadAccessAccountIDs:  []string{},
			defaultReadAccessAccountIDs:   []string{"111111111"},
			overrideWriteAccessAccountIDs: nil,
			defaultWriteAccessAccountIDs:  []string{},
		},
		IAMPoliciesTestCase{
			name:                          "test-default-read-access",
			shouldCreate:                  true,
			overrideReadAccessAccountIDs:  nil,
			defaultReadAccessAccountIDs:   []string{"11111111"},
			overrideWriteAccessAccountIDs: nil,
			defaultWriteAccessAccountIDs:  []string{},
		},
		IAMPoliciesTestCase{
			name:                          "test-override-write-access",
			shouldCreate:                  true,
			overrideReadAccessAccountIDs:  nil,
			defaultReadAccessAccountIDs:   []string{},
			overrideWriteAccessAccountIDs: []string{"11111111"},
			defaultWriteAccessAccountIDs:  []string{},
		},
		IAMPoliciesTestCase{
			name:                          "test-override-write-access-empty",
			shouldCreate:                  false,
			overrideReadAccessAccountIDs:  nil,
			defaultReadAccessAccountIDs:   []string{},
			overrideWriteAccessAccountIDs: []string{},
			defaultWriteAccessAccountIDs:  []string{"111111111"},
		},
		IAMPoliciesTestCase{
			name:                          "test-default-write-access",
			shouldCreate:                  true,
			overrideReadAccessAccountIDs:  nil,
			defaultReadAccessAccountIDs:   []string{},
			overrideWriteAccessAccountIDs: nil,
			defaultWriteAccessAccountIDs:  []string{"11111111"},
		},
		IAMPoliciesTestCase{
			name:                          "test-override-both",
			shouldCreate:                  true,
			overrideReadAccessAccountIDs:  []string{"11111111"},
			defaultReadAccessAccountIDs:   []string{},
			overrideWriteAccessAccountIDs: []string{"11111111"},
			defaultWriteAccessAccountIDs:  []string{},
		},
		IAMPoliciesTestCase{
			name:                          "test-default-both",
			shouldCreate:                  true,
			overrideReadAccessAccountIDs:  []string{"11111111"},
			defaultReadAccessAccountIDs:   []string{},
			overrideWriteAccessAccountIDs: []string{"11111111"},
			defaultWriteAccessAccountIDs:  []string{},
		},
	}

	for _, testCase := range testCases {
		// We capture the range variable to bring into the scope of the for loop, to avoid it changing while the
		// subtests are running.
		testCase := testCase

		t.Run(testCase.name, func(t *testing.T) {
			t.Parallel()

			testFolder := test_structure.CopyTerraformFolderToTemp(t, "../../", "examples/for-learning-and-testing/data-stores/ecr-repos")
			awsRegion := aws.GetRandomStableRegion(t, nil, nil)
			uniqueID := strings.ToLower(random.UniqueId())

			name := fmt.Sprintf("sample-app-%s", strings.ToLower(uniqueID))
			tfvars := map[string]interface{}{
				"aws_region": awsRegion,
				"repositories": map[string]interface{}{
					name: map[string]interface{}{
						"external_account_ids_with_read_access":  testCase.overrideReadAccessAccountIDs,
						"external_account_ids_with_write_access": testCase.overrideWriteAccessAccountIDs,
						"tags":                                   map[string]string{},
						"enable_automatic_image_scanning":        true,
					},
				},
				"default_external_account_ids_with_read_access":  testCase.defaultReadAccessAccountIDs,
				"default_external_account_ids_with_write_access": testCase.defaultWriteAccessAccountIDs,
			}
			// We work around a terraform bug where we can't pass in null values to terraform on the CLI by using tfvars
			// files
			options, varFilesFname := constructTerraformOptionsWithVarFiles(t, testFolder, tfvars)
			defer os.Remove(varFilesFname)
			planOut := terraform.InitAndPlan(t, options)
			resourceCounts := terraform.GetResourceCount(t, planOut)
			if testCase.shouldCreate {
				assert.Equal(t, resourceCounts.Add, 2)
			} else {
				assert.Equal(t, resourceCounts.Add, 1)
			}
			assert.Equal(t, resourceCounts.Change, 0)
			assert.Equal(t, resourceCounts.Destroy, 0)
		})
	}
}

func constructTerraformOptionsWithVarFiles(t *testing.T, terraformDir string, vars map[string]interface{}) (*terraform.Options, string) {
	out, err := json.Marshal(vars)
	require.NoError(t, err)
	fname := func() string {
		f, err := ioutil.TempFile("", "*.tfvars.json")
		require.NoError(t, err)
		defer f.Close()
		_, writeErr := f.Write(out)
		require.NoError(t, writeErr)
		return f.Name()
	}()
	terraformOptions := test.CreateBaseTerraformOptions(t, terraformDir, "")
	delete(terraformOptions.Vars, "aws_region")
	terraformOptions.VarFiles = []string{fname}
	return terraformOptions, fname
}

func validateECRRepo(t *testing.T, testFolder string) {
	name := test_structure.LoadString(t, testFolder, "repoName")
	awsRegion := test_structure.LoadString(t, testFolder, "region")
	terraformOptions := test_structure.LoadTerraformOptions(t, testFolder)
	repoUrls := terraform.OutputMap(t, terraformOptions, "ecr_repo_urls")
	repoUrl := repoUrls[name]
	imgTag := fmt.Sprintf("%s:v1", repoUrl)

	// Build and push docker image
	test_structure.RunTestStage(t, "build_and_push_docker_image", func() {
		// Delete image immediately, as we want to test pulling from ECR
		defer func() {
			cmd := shell.Command{
				Command: "docker",
				Args:    []string{"rmi", imgTag},
			}
			shell.RunCommand(t, cmd)
		}()

		buildOpts := &docker.BuildOptions{
			Tags:         []string{imgTag},
			OtherOptions: []string{"--no-cache"},
		}
		docker.Build(t, "../fixtures/simple-docker-img", buildOpts)

		test.AuthECRAndPushImages(t, awsRegion, []string{imgTag})
	})

	// Validate the image in ECR by pulling it down and running it.
	test_structure.RunTestStage(t, "validate_image", func() {
		test.AuthECRAndCallFn(t, awsRegion, func() {
			runOpts := &docker.RunOptions{Remove: true}
			out := docker.Run(t, imgTag, runOpts)
			assert.Contains(t, out, "Hello from Docker!")
		})
	})

}
