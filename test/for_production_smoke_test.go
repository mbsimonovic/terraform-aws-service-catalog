package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/gruntwork-cli/files"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/mattn/go-zglob"
	"github.com/stretchr/testify/require"
)

func TestSmokeForProductionExamples(t *testing.T) {
	t.Parallel()

	infraLiveRoot := test_structure.CopyTerraformFolderToTemp(t, "../", filepath.Join("examples", "for-production", "infrastructure-live"))

	// For each directory, run validate-all. Note that we can't run validate-all at the root due to a limitation of
	// find_in_parent_folders where it will not search the current directory, and thus can't find the common.hcl when it
	// tries to process the root terragrunt.hcl file.
	allItemsInLive, err := zglob.Glob(filepath.Join(infraLiveRoot, "*"))
	require.NoError(t, err)
	allAccounts := []string{}
	for _, item := range allItemsInLive {
		if files.IsDir(item) {
			allAccounts = append(allAccounts, item)
		}
	}
	for _, account := range allAccounts {
		t.Run(filepath.Base(account), func(t *testing.T) {
			t.Parallel()

			opts := &terraform.Options{
				TerraformBinary: "terragrunt",
				TerraformDir:    account,
			}
			_, err := terraform.RunTerraformCommandE(t, opts, terraform.FormatArgs(opts, "validate-all")...)
			require.NoError(t, err)
		})
	}
}
