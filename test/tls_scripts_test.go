package test

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/docker"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/logger"
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

	scriptsDir := "../modules/tls-scripts"
	tmpBaseDir := "/tmp"

	// Download RDS CA Certs vars
	downloadPath := filepath.Join(tmpBaseDir, "rds-cert")

	// Create TLS Cert vars
	certBaseDir := filepath.Join(tmpBaseDir, "vault-blueprint")
	certOutputDir := filepath.Join(certBaseDir, "modules/private-tls-cert")
	createCertFiles := []string{"ca.crt.pem", "my-app.cert", "my-app.key.pem.kms.encrypted"}

	// Generate Trust Stores vars
	packageKafkaDir := filepath.Join(tmpBaseDir, "package-kafka")
	sslDir := filepath.Join(tmpBaseDir, "ssl")
	trustStoresFiles := []string{"kafka.server.ca.default.pem", "kafka.server.cert.default.pem", "keystore/kafka.server.keystore.default.jks", "truststore/kafka.server.truststore.default.jks"}

	// Configure the tag to use on the Docker image.
	tag := "gruntwork/tls-scripts-docker-image"
	buildOptions := &docker.BuildOptions{
		Tags: []string{tag},
		BuildArgs: []string{
			"GITHUB_OAUTH_TOKEN",
			"SSH_PRIVATE_KEY=\"$(cat ~/.ssh/id_rsa)\"",
			"SSH_PUBLIC_KEY=\"$(cat ~/.ssh/id_rsa.pub)\"",
			"SSH_PASSPHRASE",
		},
	}

	// Build the Docker image.
	docker.Build(t, scriptsDir, buildOptions)

	var testCases = []struct {
		name     string
		deploy   func()
		validate func()
		cleanup  func()
	}{
		{
			"CreateTlsCert",
			func() {
				// Run the Docker image.
				runOpts := &docker.RunOptions{
					Command: []string{
						"create-tls-cert.sh",
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
					EnvironmentVariables: []string{
						"AWS_ACCESS_KEY_ID",
						"AWS_SECRET_ACCESS_KEY",
						"AWS_SESSION_TOKEN", // only set if you're using temporary creds, mfa, etc
					},

					Volumes: []string{
						fmt.Sprintf("%s:%s", tmpBaseDir, tmpBaseDir),
					},
				}

				docker.Run(t, tag, runOpts)
			},

			func() {
				for _, file := range createCertFiles {
					require.Truef(
						t,
						files.FileExists(filepath.Join(certOutputDir, file)),
						"Error Validating Create TLS Cert %s",
						file,
					)
				}
			},
			func() {
				os.RemoveAll(certOutputDir)
			},
		},
		{
			"DownloadRdsCaCert",
			func() {
				// Run the Docker image.
				runOpts := &docker.RunOptions{
					Command: []string{
						"download-rds-ca-certs.sh",
						downloadPath,
					},
					EnvironmentVariables: []string{
						"AWS_ACCESS_KEY_ID",
						"AWS_SECRET_ACCESS_KEY",
						"AWS_SESSION_TOKEN", // only set if you're using temporary creds, mfa, etc
					},

					Volumes: []string{
						fmt.Sprintf("%s:%s", tmpBaseDir, tmpBaseDir),
					},
				}

				docker.Run(t, tag, runOpts)
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
				// Run the Docker image.
				logger.Logf(t, "%s", os.Getenv("GITHUB_OAUTH_TOKEN"))
				runOpts := &docker.RunOptions{
					Command: []string{
						"generate-trust-stores.sh",
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
					EnvironmentVariables: []string{
						"AWS_ACCESS_KEY_ID",
						"AWS_SECRET_ACCESS_KEY",
						"AWS_SESSION_TOKEN", // only set if you're using temporary creds, mfa, etc
					},

					Volumes: []string{
						fmt.Sprintf("%s:%s", tmpBaseDir, tmpBaseDir),
					},
				}

				docker.Run(t, tag, runOpts)
			},
			func() {
				for _, file := range trustStoresFiles {
					require.Truef(
						t,
						files.FileExists(fmt.Sprintf("%s/%s", sslDir, file)),
						"Error Validating Generate Trust Stores %s",
						file,
					)
				}
			},
			func() {
				os.RemoveAll(packageKafkaDir)
				os.RemoveAll(sslDir)
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
