package test

import (
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/docker"
	"github.com/gruntwork-io/terratest/modules/files"
	// "github.com/gruntwork-io/terratest/modules/logger"
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

	requireEnvVar(t, "GITHUB_OAUTH_TOKEN")

	scriptsPath := "../modules/tls-scripts"

	// Download RDS CA Certs vars
	downloadPath := fmt.Sprintf("%s/.test-data/rds-cert", scriptsPath)

	// Create TLS Cert vars
	certBasePath := "/tmp/vault-blueprint"
	outputPath := fmt.Sprintf("%s/modules/private-tls-cert", certBasePath)
	createCertFiles := []string{"ca.crt.pem", "my-app.cert", "my-app.key.pem.kms.encrypted"}

	// Generate Trust Stores vars
	packageKafkaPath := "/tmp/package-kafka"
	sslPath := "/tmp/ssl"
	trustStoresFiles := []string{"kafka.server.ca.default.pem", "kafka.server.cert.default.pem", "keystore/kafka.server.keystore.default.jks", "truststore/kafka.server.truststore.default.jks"}

	// Determined that this is set locally!
	// ghtoken := os.Getenv("GITHUB_OAUTH_TOKEN")
	// logger.Logf(t, "github token is %s", ghtoken)

	var testCases = []struct {
		name     string
		deploy   func()
		validate func()
		cleanup  func()
	}{
		{
			"CreateTlsCert",
			func() {
				// Configure the tag to use on the Docker image.
				tag := "gruntwork/tls-scripts-docker-image"
				buildOptions := &docker.BuildOptions{
					Tags:      []string{tag},
					BuildArgs: []string{"GITHUB_OAUTH_TOKEN"}, // Let Docker look it up
				}

				// Build the Docker image.
				docker.Build(t, scriptsPath, buildOptions)

				// Run the Docker image.
				runOpts := &docker.RunOptions{
					Command: []string{
						"/modules/tls-scripts/create-tls-cert.sh",
						"--ca-path",
						"ca.crt.pem",
						"--cert-path",
						"my-app.cert",
						"--key-path",
						"my-app.key.pem",
						"--company-name",
						"Acme",
						"--kms-key-id",
						"alias/cmk-dev",
						"--aws-region",
						"us-east-1",
					},
					EnvironmentVariables: []string{"GITHUB_OAUTH_TOKEN"}, // ???
					Volumes:              []string{"/Users/rhozen/Development/aws-service-catalog/modules/tls-scripts:/modules/tls-scripts", "/tmp:/tmp"},
				}

				docker.Run(t, tag, runOpts)

				// createTlsCert := shell.Command{
				// 	Command: fmt.Sprintf("%s/create-tls-cert.sh", scriptsPath),
				// 	Args: []string{
				// 		"--ca-path",
				// 		"ca.crt.pem",
				// 		"--cert-path",
				// 		"my-app.cert",
				// 		"--key-path",
				// 		"my-app.key.pem",
				// 		"--company-name",
				// 		"Acme",
				// 		"--kms-key-id",
				// 		"alias/cmk-dev",
				// 		"--aws-region",
				// 		"us-east-1",
				// 	},
				// }

				// shell.RunCommand(t, createTlsCert)

			},

			func() {
				for _, file := range createCertFiles {
					require.Truef(
						t,
						files.FileExists(fmt.Sprintf("%s/%s", outputPath, file)),
						"Error Validating Create TLS Cert %s",
						file,
					)
				}
			},
			func() {
				os.RemoveAll(certBasePath)
			},
		},
		{
			"DownloadRdsCaCert",
			func() {
				downloadRdsCaCerts := shell.Command{
					Command: fmt.Sprintf("%s/download-rds-ca-certs.sh", scriptsPath),
					Args: []string{
						downloadPath,
					},
				}

				shell.RunCommand(t, downloadRdsCaCerts)
			},
			func() {
				require.True(
					t,
					files.FileExists(downloadPath),
					"Error Validating Download RDS CA Cert %s",
					downloadPath,
				)
			},
			func() {
				os.RemoveAll(downloadPath)
			},
		},
		{
			"GenerateTrustStores",
			func() {
				generateTrustStores := shell.Command{
					Command: fmt.Sprintf("%s/generate-trust-stores.sh", scriptsPath),
					Args: []string{
						"--keystore-name",
						"kafka",
						"--store-path",
						"/tmp/ssl",
						"--vpc-name",
						"default",
						"--company-name",
						"Acme",
						"--company-org-unit",
						"IT",
						"--company-city",
						"Phoenix",
						"--company-state",
						"AZ",
						"--company-country",
						"US",
						"--kms-key-id",
						"alias/cmk-dev",
						"--aws-region",
						"us-east-1",
					},
				}

				shell.RunCommand(t, generateTrustStores)
			},
			func() {
				for _, file := range trustStoresFiles {
					require.Truef(
						t,
						files.FileExists(fmt.Sprintf("%s/%s", sslPath, file)),
						"Error Validating Generate Trust Stores %s",
						file,
					)
				}
			},
			func() {
				os.RemoveAll(packageKafkaPath)
				os.RemoveAll(sslPath)
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
