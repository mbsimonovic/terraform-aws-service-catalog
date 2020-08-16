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
// - Docker needs to be running
// - Your github-oauth-token must be exported in GITHUB_OAUTH_TOKEN
// - AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY need to be set
// - If you're using temporary credentials, AWS_SESSION_TOKEN needs to be set
// - You need to provide a KMS CMK in TLS_SCRIPTS_KMS_KEY_ID and its region in TLS_SCRIPTS_AWS_REGION

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
	tmpBaseDir := "tmp"

	// Download RDS CA Certs vars
	downloadPath := filepath.Join(tmpBaseDir, "rds-cert")

	// Create TLS Cert vars
	createTLSDir := filepath.Join(tmpBaseDir, "tls")
	createCertFiles := []string{"ca.crt.pem", "my-app.cert", "my-app.key.pem.kms.encrypted"}

	// Generate Trust Stores vars
	sslDir := filepath.Join(tmpBaseDir, "ssl")
	trustStoresFiles := []string{"kafka.server.ca.default.pem", "kafka.server.cert.default.pem", "keystore/kafka.server.keystore.default.jks", "truststore/kafka.server.truststore.default.jks"}

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
				// Store the cert name in .test_data so we can clean it up
				// if test stages are skipped
				certNameInIam := fmt.Sprintf("tls-scripts-test-%s", random.UniqueId())
				test_structure.SaveString(t, scriptsDir, "certNameInIam", certNameInIam)

				docker.RunDockerCompose(
					t,
					&docker.Options{},
					"-f",
					filepath.Join(scriptsDir, "docker-compose.yml"),
					"run",
					"tls",
					"--ca-path",
					"ca.crt.pem",
					"--cert-path",
					"my-app.cert",
					"--key-path",
					"my-app.key.pem",
					"--company-name",
					"Acme",
					"--upload-to-iam",
					"--cert-name-in-iam",
					certNameInIam,
					"--kms-key-id",
					kmsKeyId,
					"--aws-region",
					awsRegion,
				)
			},

			func() {
				for _, file := range createCertFiles {
					require.FileExistsf(
						t,
						filepath.Join(scriptsDir, createTLSDir, file),
						"Error Validating Create TLS Cert %s",
						filepath.Join(scriptsDir, createTLSDir, file),
					)
				}
			},
			func() {
				os.RemoveAll(filepath.Join(scriptsDir, createTLSDir))

				// Remove server certificate from IAM
				certNameInIam := test_structure.LoadString(t, scriptsDir, "certNameInIam")
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
				docker.RunDockerCompose(
					t,
					&docker.Options{},
					"-f",
					filepath.Join(scriptsDir, "docker-compose.yml"),
					"run",
					"trust-stores",
					"--keystore-name",
					"kafka",
					"--store-path",
					sslDir,
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
						filepath.Join(scriptsDir, sslDir, file),
						"Error Validating Generate Trust Stores %s",
						filepath.Join(scriptsDir, sslDir, file),
					)
				}
			},
			func() {
				os.RemoveAll(filepath.Join(scriptsDir, sslDir))
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
