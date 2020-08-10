package test

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/aws/aws-sdk-go/service/iam"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/docker"
	"github.com/gruntwork-io/terratest/modules/random"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	"github.com/stretchr/testify/require"
)

// To run this test suite, a number of requirements must be met:
// - docker needs to be running
// - your github-oauth-token must be exported in GITHUB_OAUTH_TOKEN
// - AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY need to be set
// - if you're using temporary credentials, AWS_SESSION_TOKEN needs to be set
// - you need to provide a KMS CMK in TLS_SCRIPTS_KMS_KEY_ID and its region in TLS_SCRIPTS_AWS_REGION

func TestTlsScripts(t *testing.T) {
	t.Parallel()

	// Uncomment the items below to skip certain parts of the test
	// os.Setenv("TERRATEST_REGION", "us-east-1")
	// os.Setenv("SKIP_deploy", "true")
	// os.Setenv("SKIP_validate", "true")
	// os.Setenv("SKIP_cleanup", "true")

	requireEnvVar(t, "GITHUB_OAUTH_TOKEN")
	requireEnvVar(t, "AWS_ACCESS_KEY_ID")
	requireEnvVar(t, "AWS_SECRET_ACCESS_KEY")
	requireEnvVar(t, "TLS_SCRIPTS_KMS_KEY_ID")
	requireEnvVar(t, "TLS_SCRIPTS_AWS_REGION")

	scriptsDir := "../modules/tls-scripts"
	tmpBaseDir := "/tmp"

	// Download RDS CA Certs vars
	downloadPath := filepath.Join(tmpBaseDir, "rds-cert")

	// Create TLS Cert vars
	certBaseDir := filepath.Join(tmpBaseDir, "vault-blueprint")
	certOutputDir := filepath.Join(certBaseDir, "modules/private-tls-cert")
	createCertFiles := []string{"ca.crt.pem", "my-app.cert", "my-app.key.pem.kms.encrypted"}
	// The name of the server certificate that we upload to IAM.
	certNameInIam := fmt.Sprintf("tls-scripts-test-%s", random.UniqueId())

	// Generate Trust Stores vars
	sslDir := filepath.Join(tmpBaseDir, "ssl")
	trustStoresFiles := []string{"kafka.server.ca.default.pem", "kafka.server.cert.default.pem", "keystore/kafka.server.keystore.default.jks", "truststore/kafka.server.truststore.default.jks"}

	// Configure the tag to use on the Docker image.
	tag := "gruntwork/tls-scripts-docker-image"
	buildOptions := &docker.BuildOptions{
		Tags: []string{tag},
		BuildArgs: []string{
			"GITHUB_OAUTH_TOKEN",
		},
	}

	// Build the Docker image.
	docker.Build(t, scriptsDir, buildOptions)

	// This kmsKeyId is used for testing against Gruntwork's test account.
	// You will have to change it to use a key available in your account.
	// kmsKeyId := "alias/dedicated-test-key"
	kmsKeyId := os.Getenv("TLS_SCRIPTS_KMS_KEY_ID")
	// This region should match where the key is located.
	// awsRegion := "us-east-1"
	awsRegion := os.Getenv("TLS_SCRIPTS_AWS_REGION")

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
						kmsKeyId,
						"--aws-region",
						awsRegion,
						"--upload-to-iam",
						"--cert-name-in-iam",
						certNameInIam,
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
					require.FileExistsf(
						t,
						filepath.Join(certOutputDir, file),
						"Error Validating Create TLS Cert %s",
						file,
					)
				}
			},
			func() {
				os.RemoveAll(certBaseDir)

				// Remove server certificate from IAM
				sess, err := aws.NewAuthenticatedSession(awsRegion)
				require.NoError(t, err)
				iamClient := iam.New(sess)
				input := iam.DeleteServerCertificateInput{ServerCertificateName: &certNameInIam}
				_, err = iamClient.DeleteServerCertificate(&input)
				require.NoError(t, err)
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
					Volumes: []string{
						fmt.Sprintf("%s:%s", tmpBaseDir, tmpBaseDir),
					},
				}

				docker.Run(t, tag, runOpts)
			},
			func() {
				require.FileExistsf(
					t,
					downloadPath,
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
						kmsKeyId,
						"--aws-region",
						awsRegion,
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
					require.FileExistsf(
						t,
						fmt.Sprintf("%s/%s", sslDir, file),
						"Error Validating Generate Trust Stores %s",
						file,
					)
				}
			},
			func() {
				os.RemoveAll(sslDir)
			},
		},
	}

	for _, testCase := range testCases {
		testCase := testCase
		t.Run(testCase.name, func(t *testing.T) {
			defer test_structure.RunTestStage(t, "cleanup", testCase.cleanup)
			test_structure.RunTestStage(t, "deploy", testCase.deploy)
			test_structure.RunTestStage(t, "validate", testCase.validate)
		})
	}
}
