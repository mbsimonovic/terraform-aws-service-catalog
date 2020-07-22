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

	// Download RDS CA Certs vars
	downloadPath := fmt.Sprintf("%s/.test-data/rds-cert", scriptsPath)

	// Create TLS Cert vars
	outputPath := "/tmp/vault-blueprint/modules/private-tls-cert"
	createCertFiles := []string{"ca.crt.pem", "my-app.cert", "my-app.key.pem.kms.encrypted"}

	// Generate Trust Stores vars
	packageKafkaPath := "/tmp/package-kafka"
	sslPath := "/tmp/ssl"
	trustStoresFiles := []string{"kafka.server.ca.default.pem", "kafka.server.cert.default.pem", "keystore/kafka.server.keystore.default.jks", "truststore/kafka.server.truststore.default.jks"}

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
							"[ -f %s/%s ] && [ -f %s/%s ] && [ -f %s/%s ] && exit 0 || exit 1",
							outputPath,
							createCertFiles[0],
							outputPath,
							createCertFiles[1],
							outputPath,
							createCertFiles[2],
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
		{
			"GenerateTrustStores",
			func() {
				generateTrustStores := shell.Command{
					Command: "bash",
					Args: []string{
						"-c",
						fmt.Sprintf(
							"%s/generate-trust-stores.sh --keystore-name kafka --store-path /tmp/ssl --vpc-name default --company-name Acme --company-org-unit IT --company-city Phoenix --company-state AZ --company-country US --kms-key-id alias/cmk-dev --aws-region us-east-1",
							scriptsPath,
						),
					},
				}

				shell.RunCommand(t, generateTrustStores)
			},
			func() {
				checkGenerateTrustStores := shell.Command{
					Command: "bash",
					Args: []string{
						"-c",
						fmt.Sprintf(
							"[ -f %s/%s ] && [ -f %s/%s ] && [ -f %s/%s ] && [ -f %s/%s ]",
							sslPath,
							trustStoresFiles[0],
							sslPath,
							trustStoresFiles[1],
							sslPath,
							trustStoresFiles[2],
							sslPath,
							trustStoresFiles[3],
						),
					},
				}

				err := shell.RunCommandE(t, checkGenerateTrustStores)
				require.NoError(t, err, "Error Validating Generate Trust Stores")
			},
			func() {
				cleanup := shell.Command{
					Command: "bash",
					Args: []string{
						"-c",
						fmt.Sprintf(
							"rm -rf %s && rm -rf %s",
							packageKafkaPath,
							sslPath,
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
