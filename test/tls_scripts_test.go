package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/shell"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

func TestTlsScripts(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "us-east-1")
	// os.Setenv("SKIP_deploy", "true")
	// os.Setenv("SKIP_validate", "true")
	// os.Setenv("SKIP_cleanup", "true")

	scriptsPath := "../modules/tls-scripts"
	testFolderPath := fmt.Sprintf("%s/.test-data", scriptsPath)
	downloadPath := fmt.Sprintf("%s/rds-cert", testFolderPath)

	outputPath := "/tmp/vault-blueprint/modules/private-tls-cert"
	files := []string{"ca.crt.pem", "my-app.cert"}

	var testCases = []struct {
		name     string
		deploy   func()
		validate func()
		cleanup  func()
	}{
		{
			"CreateTlsCert",
			func() {
				createTlsCert := shell.Command{
					Command: "bash",
					Args: []string{
						"-c",
						fmt.Sprintf(
							"%s/create-tls-cert.sh --ca-path ca.crt.pem --cert-path my-app.cert --key-path my-app.key.pem --company-name Acme --kms-key-id alias/cmk-dev --aws-region us-east-1",
							scriptsPath,
						),
					},
				}

				shell.RunCommand(t, createTlsCert)

			},
			func() {
				checkCerts := shell.Command{
					Command: "bash",
					Args: []string{
						"-c",
						fmt.Sprintf(
							"[ -f %s/%s ] && [ -f %s/%s ] && exit 0 || exit 1",
							outputPath,
							files[0],
							outputPath,
							files[1],
						),
					},
				}

				err := shell.RunCommandE(t, checkCerts)
				require.NoError(t, err, "Error Validating Cert Creation")
			},
			func() {
				cleanup := shell.Command{
					Command: "bash",
					Args: []string{
						"-c",
						fmt.Sprint(
							"rm -rf /tmp/vault-blueprint",
						),
					},
				}

				shell.RunCommand(t, cleanup)
			},
		},
		{
			"DownloadRdsCaCert",
			func() {
				downloadRdsCaCerts := shell.Command{
					Command: "bash",
					Args: []string{
						"-c",
						fmt.Sprintf(
							"%s/download-rds-ca-certs.sh %s",
							scriptsPath,
							downloadPath,
						),
					},
				}

				shell.RunCommand(t, downloadRdsCaCerts)
			},
			func() {
				checkDownload := shell.Command{
					Command: "bash",
					Args: []string{
						"-c",
						fmt.Sprintf(
							"[ -f %s ] && exit 0 || exit 1",
							downloadPath,
						),
					},
				}

				err := shell.RunCommandE(t, checkDownload)
				require.NoError(t, err, "Error Validating Download RDS CA Cert")
			},
			func() {
				cleanup := shell.Command{
					Command: "bash",
					Args: []string{
						"-c",
						fmt.Sprintf(
							"rm %s",
							downloadPath,
						),
					},
				}

				shell.RunCommand(t, cleanup)
			},
		},
	}

	for _, testCase := range testCases {
		defer test_structure.RunTestStage(t, "cleanup", testCase.cleanup)
	}

	for _, testCase := range testCases {
		test_structure.RunTestStage(t, "deploy", testCase.deploy)
	}

	for _, testCase := range testCases {
		test_structure.RunTestStage(t, "validate", testCase.validate)
	}
}
