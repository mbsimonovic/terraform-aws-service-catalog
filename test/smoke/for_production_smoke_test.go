package smoke

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/go-commons/files"
	"github.com/gruntwork-io/terratest/modules/collections"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/mattn/go-zglob"
	"github.com/stretchr/testify/require"
)

// Folders in infrastructure live that are not terragrunt examples.
var notTerragruntExamples = []string{"docs", "_ci", "vars", "_envcommon"}

func TestSmokeForProductionExamples(t *testing.T) {
	t.Parallel()

	infraLiveRoot := test_structure.CopyTerraformFolderToTemp(t, "../../", filepath.Join("examples", "for-production", "infrastructure-live"))

	// For each directory, run validate-all. Note that we can't run validate-all at the root due to a limitation of
	// find_in_parent_folders where it will not search the current directory, and thus can't find the common.hcl when it
	// tries to process the root terragrunt.hcl file. We also skip the ci and docs folders.
	allItemsInLive, err := zglob.Glob(filepath.Join(infraLiveRoot, "*"))
	require.NoError(t, err)
	allAccounts := []string{}
	for _, item := range allItemsInLive {
		if files.IsDir(item) && !collections.ListContains(notTerragruntExamples, filepath.Base(item)) {
			allAccounts = append(allAccounts, item)
		}
	}
	// We run validate-all in each account sequentially. For some reason, running in parallel cause mysterious errors in
	// git clone phase for all but one of the accounts that manage to "win" the race.
	for _, account := range allAccounts {
		t.Run(filepath.Base(account), func(t *testing.T) {
			opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformBinary: "terragrunt",
				TerraformDir:    account,
			})

			// Terragrunt ignores dependency ordering when running run-all validate, which causes a race condition
			// on init. To avoid this, we add a retryable error to keep trying when we hit the race condition.
			opts.RetryableTerraformErrors[".*exit status 126.*"] = "Race condition caused file permission errors"
			terraform.RunTerraformCommand(
				t,
				opts,
				terraform.FormatArgs(opts, "run-all", "validate")...,
			)
		})
	}
}
