package validation

import (
	"os"
	"path/filepath"
	"testing"

	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	"github.com/stretchr/testify/require"
)

// TestValidateAllModulesAndExamples recursively finds all modules and examples (by default) subdirectories in
// the repo and runs Terraform InitAndValidate on them to flush out missing variables, typos, unused vars, etc
func TestValidateAllModulesAndExamples(t *testing.T) {
	t.Parallel()

	cwd, err := os.Getwd()
	require.NoError(t, err)

	// Due to a Terraform bug (https://github.com/hashicorp/terraform/issues/28490), 'terraform validate' will fail on
	// any module that uses configuration_aliases, so we have to exclude all our multi-region modules, as they all use
	// that feature. Fortunately, validate will still run against these modules when we run it in the examples folder,
	// and it will pass there because all our examples pass in the full set of providers expected by
	// configuration_aliases.
	excludeDirs := []string{
		"modules/landingzone/account-baseline-app",
		"modules/landingzone/account-baseline-root",
		"modules/landingzone/account-baseline-security",
		"modules/mgmt/ecs-deploy-runner",
	}

	opts, optsErr := test_structure.NewValidationOptions(filepath.Join(cwd, "../.."), []string{}, excludeDirs)
	require.NoError(t, optsErr)

	test_structure.ValidateAllTerraformModules(t, opts)
}
