package test

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/aws/aws-sdk-go/service/acm"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/docker"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/shell"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	"github.com/stretchr/testify/require"
)

// To run this test suite, a number of requirements must be met:
// - Ensure Docker is running
// - Export your GitHub Personal Access Token in GITHUB_OAUTH_TOKEN
//     - e.g.: export GITHUB_OAUTH_TOKEN=7d1c645272775xxxxd5cd68bb2dxxxxeb35858c9
// - Export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
// - If you're using temporary credentials, export AWS_SESSION_TOKEN
// - Export a KMS CMK in TLS_SCRIPTS_KMS_KEY_ID
//     - e.g.: export TLS_SCRIPTS_KMS_KEY_ID=alias/dedicated-test-key
// - Export a region in TLS_SCRIPTS_AWS_REGION
//     - e.g.: export TLS_SCRIPTS_AWS_REGION=us-east-1

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
	tmpBaseDir := "tls"

	// Create TLS Cert vars
	createCertFiles := []string{"CA.crt", "app.crt", "app.key"}
	createCertEncryptedFiles := []string{"CA.crt", "app.crt", "app.key.kms.encrypted"}

	// Download RDS CA Certs vars
	downloadPath := filepath.Join(tmpBaseDir, "rds-cert")

	// Generate Trust Stores vars
	trustStoresDir := filepath.Join(tmpBaseDir, "trust-stores")
	trustStoresFiles := []string{"kafka.server.ca.default.pem", "kafka.server.cert.default.pem", "keystore/kafka.server.keystore.default.jks", "truststore/kafka.server.truststore.default.jks"}

	// This KMS key id should match the key you'd like to use to encrypt the secret
	// awsRegion := "alias/dedicated-test-key"
	kmsKeyId := os.Getenv("TLS_SCRIPTS_KMS_KEY_ID")
	// This region should match where you want the secrets stored in AWS Secrets Manager.
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
				// Store the certs locally in a random id folder for this test.
				storePath := fmt.Sprintf("tls/certs_%s", random.UniqueId())
				test_structure.SaveString(t, scriptsDir, "storePath", storePath)

				// Run the build step first so that the build output doesn't go to stdout during the compose step.
				docker.RunDockerCompose(
					t,
					&docker.Options{},
					"-f",
					filepath.Join(scriptsDir, "docker-compose.yml"),
					"build",
					"certs",
				)

				docker.RunDockerCompose(
					t,
					&docker.Options{},
					"-f",
					filepath.Join(scriptsDir, "docker-compose.yml"),
					"run",
					"certs",
					"--cn",
					"acme.com",
					"--country",
					"US",
					"--state",
					"Arizona",
					"--city",
					"Phoenix",
					"--org",
					"Gruntwork",
					"--store-path",
					storePath,
				)
			},

			func() {
				storePath := test_structure.LoadString(t, scriptsDir, "storePath")

				for _, file := range createCertFiles {
					require.FileExistsf(
						t,
						filepath.Join(scriptsDir, storePath, file),
						"Error Validating Create TLS Cert %s",
						filepath.Join(scriptsDir, storePath, file),
					)
				}
			},
			func() {
				// Because CircleCI runs this test as root, the output folders cannot be cleaned up
				// as the test/circleci user. Therefore we have to sudo chown that directory.
				cmd := shell.Command{
					Command: "whoami",
					Args:    []string{},
				}
				username := shell.RunCommandAndGetOutput(t, cmd)

				if username == "circleci" {

					cmd = shell.Command{
						Command: "sudo",
						Args: []string{
							"chown",
							"-R",
							fmt.Sprintf("%d:%d", os.Getuid(), os.Getuid()),
							filepath.Join(scriptsDir, tmpBaseDir),
						},
					}
					shell.RunCommand(t, cmd)
				}

				storePath := test_structure.LoadString(t, scriptsDir, "storePath")
				os.RemoveAll(filepath.Join(scriptsDir, storePath))
			},
		},
		{
			"CreateTlsCert_WithUploadStoreAndEncryption",
			func() {
				// Store the secret name in .test_data so we can clean it up if test stages are skipped.
				suffix := random.UniqueId()
				storePath := fmt.Sprintf("tls/certs_%s", suffix)
				test_structure.SaveString(t, scriptsDir, "storePathEnc", storePath)

				certSecretName := fmt.Sprintf("tls-secrets-%s", suffix)
				test_structure.SaveString(t, scriptsDir, "certSecretName", certSecretName)

				// Run the build step first so that the build output doesn't go to stdout during the compose step.
				docker.RunDockerCompose(
					t,
					&docker.Options{},
					"-f",
					filepath.Join(scriptsDir, "docker-compose.yml"),
					"build",
					"certs",
				)

				// Save output to grab the Certificate ARN output by the script.
				out := docker.RunDockerComposeAndGetStdOut(
					t,
					&docker.Options{},
					"-f",
					filepath.Join(scriptsDir, "docker-compose.yml"),
					"run",
					"certs",
					"--cn",
					"acme.com",
					"--country",
					"US",
					"--state",
					"Arizona",
					"--city",
					"Phoenix",
					"--org",
					"Gruntwork",
					"--aws-region",
					awsRegion,
					"--store-in-sm",
					"--secret-name",
					certSecretName,
					"--kms-key-id",
					kmsKeyId,
					"--upload-to-acm",
					"--store-path",
					storePath,
				)

				// Save the Certificate ARN for cleanup.
				test_structure.SaveString(t, scriptsDir, "certARNinAWS", out)
			},

			func() {
				storePath := test_structure.LoadString(t, scriptsDir, "storePathEnc")

				for _, file := range createCertEncryptedFiles {
					require.FileExistsf(
						t,
						filepath.Join(scriptsDir, storePath, file),
						"Error Validating Create TLS Cert %s",
						filepath.Join(scriptsDir, storePath, file),
					)
				}
			},
			func() {
				// Because CircleCI runs this test as root, the output folders cannot be cleaned up
				// as the test/circleci user. Therefore we have to sudo chown that directory.
				cmd := shell.Command{
					Command: "whoami",
					Args:    []string{},
				}
				username := shell.RunCommandAndGetOutput(t, cmd)

				if username == "circleci" {

					cmd = shell.Command{
						Command: "sudo",
						Args: []string{
							"chown",
							"-R",
							fmt.Sprintf("%d:%d", os.Getuid(), os.Getuid()),
							filepath.Join(scriptsDir, tmpBaseDir),
						},
					}
					shell.RunCommand(t, cmd)
				}

				storePath := test_structure.LoadString(t, scriptsDir, "storePathEnc")
				os.RemoveAll(filepath.Join(scriptsDir, storePath))

				sess, err := aws.NewAuthenticatedSession(awsRegion)
				require.NoError(t, err)

				// Remove certificate from ACM using ARN
				certARN := test_structure.LoadString(t, scriptsDir, "certARNinAWS")
				acmClient := acm.New(sess)
				input := acm.DeleteCertificateInput{CertificateArn: &certARN}
				_, err = acmClient.DeleteCertificate(&input)
				require.NoError(t, err)

				// Delete from Secrets Manager, too.
				certSecretName := test_structure.LoadString(t, scriptsDir, "certSecretName")
				smClient := secretsmanager.New(sess)
				secretInput := secretsmanager.DeleteSecretInput{SecretId: &certSecretName}
				_, err = smClient.DeleteSecret(&secretInput)
				require.NoError(t, err)
			},
		},
		{
			"DownloadRdsCaCert",
			func() {
				docker.RunDockerCompose(
					t,
					&docker.Options{},
					"-f",
					filepath.Join(scriptsDir, "docker-compose.yml"),
					"run",
					"rds",
					downloadPath,
				)
			},
			func() {
				require.FileExistsf(
					t,
					filepath.Join(scriptsDir, downloadPath),
					"Error Validating Download RDS CA Cert %s",
					filepath.Join(scriptsDir, downloadPath),
				)
			},
			func() {
				os.RemoveAll(filepath.Join(scriptsDir, downloadPath))
			},
		},
		{
			"GenerateTrustStores",
			func() {
				// Store the secret name in .test_data so we can clean it up if test stages are skipped.
				storesSecretName := fmt.Sprintf("trust-stores-%s", random.UniqueId())
				test_structure.SaveString(t, scriptsDir, "storesSecretName", storesSecretName)

				docker.RunDockerCompose(
					t, &docker.Options{},
					"-f",
					filepath.Join(scriptsDir, "docker-compose.yml"),
					"run",
					"trust-stores",
					"--keystore-name",
					"kafka",
					"--secret-name",
					storesSecretName,
					"--store-path",
					trustStoresDir,
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
				)
			},
			func() {
				for _, file := range trustStoresFiles {
					require.FileExistsf(
						t,
						filepath.Join(scriptsDir, trustStoresDir, file),
						"Error Validating Generate Trust Stores %s",
						filepath.Join(scriptsDir, trustStoresDir, file),
					)
				}
			},
			func() {
				os.RemoveAll(filepath.Join(scriptsDir, trustStoresDir))

				// Delete from Secrets Manager, too.
				storesSecretName := test_structure.LoadString(t, scriptsDir, "storesSecretName")
				sess, err := aws.NewAuthenticatedSession(awsRegion)
				require.NoError(t, err)
				smClient := secretsmanager.New(sess)
				input := secretsmanager.DeleteSecretInput{SecretId: &storesSecretName}
				_, err = smClient.DeleteSecret(&input)
				require.NoError(t, err)

				test_structure.CleanupTestData(t, fmt.Sprintf("%s/.test-data/storesSecretName.json", scriptsDir))
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
