package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/shell"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestTlsScripts(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "us-east-1")
	// os.Setenv("SKIP_deploy", "true")
	// os.Setenv("SKIP_validate", "true")
	// os.Setenv("SKIP_cleanup", "true")

	scriptsPath := "../modules/tls-scripts"
	outputPath := "/tmp/vault-blueprint/modules/private-tls-cert"
	files := []string{"ca.crt.pem", "my-app.cert"}

	// TODO: remove this comment block
	// NOTE: Keeping this here to show what the cleanup would look like.
	// However, the script outputs get overwritten if they exist,
	// and the vault-blueprint repo doesn't get recloned if it exists.
	// So in the interest of having less creation/cleanup, I don't think
	// we need a cleanup step at all.
	// defer test_structure.RunTestStage(t, "cleanup", func() {
	// 	cleanup := shell.Command{
	// 		Command: "bash",
	// 		Args: []string{
	// 			"-c",
	// 			fmt.Sprintf(
	//        // Only delete the created files because we need the cloned stuff to remain.
	//        // Alternatively we could delete the whole repo clone, but I feel that provides no benefit.
	// 				"rm -rf %s/%s %s/%s",
	// 				outputPath,
	// 				files[0],
	// 				outputPath,
	// 				files[1],
	// 			),
	// 		},
	// 	}

	// 	shell.RunCommand(t, cleanup)
	// })

	test_structure.RunTestStage(t, "deploy", func() {
		createTlsCert := shell.Command{
			Command: "bash",
			Args: []string{
				"-c",
				fmt.Sprintf(
					"%s/create-tls-cert.sh --ca-path ca.crt.pem --cert-path my-app.cert --key-path my-app.key.pem.kms.encrypted --company-name Acme --kms-key-id alias/cmk-dev --aws-region us-east-1",
					scriptsPath,
				),
			},
		}

		shell.RunCommand(t, createTlsCert)
	})

	test_structure.RunTestStage(t, "validate", func() {
		checkCerts := shell.Command{
			Command: "bash",
			Args: []string{
				"-c",
				fmt.Sprintf(
					"cat %s/%s && cat %s/%s",
					outputPath,
					files[0],
					outputPath,
					files[1],
				),
			},
		}

		shell.RunCommand(t, checkCerts)
	})
}
