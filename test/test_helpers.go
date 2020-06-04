package test

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/go-redis/redis/v8"
	_ "github.com/go-sql-driver/mysql"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const (
	maxTerraformRetries          = 3
	sleepBetweenTerraformRetries = 5 * time.Second
)

var (
	// Set up terratest to retry on known failures
	retryableTerraformErrors = map[string]string{
		// `terraform init` frequently fails in CI due to network issues accessing plugins. The reason is unknown, but
		// eventually these succeed after a few retries.
		".*unable to verify signature.*":             "Failed to retrieve plugin due to transient network error.",
		".*unable to verify checksum.*":              "Failed to retrieve plugin due to transient network error.",
		".*no provider exists with the given name.*": "Failed to retrieve plugin due to transient network error.",
		".*registry service is unreachable.*":        "Failed to retrieve plugin due to transient network error.",
	}
)

// Test constants for the Gruntwork Phx DevOps account
const (
	baseDomainForTest = "gruntwork.in"
	acmDomainForTest  = "*.gruntwork.in"
)

// Regions in Gruntwork Phx DevOps account that have ACM certs and t3.micro instances in all AZs
var regionsForEc2Tests = []string{
	"us-east-2",
	"us-west-1",
	"us-west-2",
	"eu-west-1",
	"ap-northeast-1",
	"ap-southeast-2",
}

// Tags in Gruntwork Phx DevOps account to uniquely find Hosted Zone for baseDomainForTest
var domainNameTagsForTest = map[string]interface{}{"original": "true"}

type RDSInfo struct {
	Username   string
	Password   string
	DBName     string
	DBEndpoint string
	DBPort     string
}

// smokeTestMysql makes a "SELECT 1+1" query over the mysql protocol to the provided RDS database.
func smokeTestMysql(t *testing.T, serverInfo RDSInfo) {
	dbConnString := fmt.Sprintf(
		"%s:%s@tcp(%s:%s)/%s",
		serverInfo.Username,
		serverInfo.Password,
		serverInfo.DBEndpoint,
		serverInfo.DBPort,
		serverInfo.DBName,
	)
	db, connErr := sql.Open("mysql", dbConnString)
	require.NoError(t, connErr)
	defer db.Close()

	row := db.QueryRow("SELECT 1+1;")
	var result string
	scanErr := row.Scan(&result)
	require.NoError(t, scanErr)
	require.Equal(t, result, "2")
}

func smokeTestMysqlWithKubernetes(t *testing.T, kubectlOptions *k8s.KubectlOptions, serverInfo RDSInfo) {
	defer k8s.RunKubectl(t, kubectlOptions, "delete", "pod", "mysql")
	k8s.RunKubectl(t, kubectlOptions, "run", "--generator=run-pod/v1", "--image", "mysql", "mysql", "--", "sleep", "9999999")

	kubectlExecMysqlCommand := []string{
		"exec", "mysql", "--", "mysql",
		"-h", serverInfo.DBEndpoint,
		"-u", serverInfo.Username,
		fmt.Sprintf("--password=%s", serverInfo.Password),
		"-P", serverInfo.DBPort,
		"--ssl-mode", "DISABLED",
		"-e", "SELECT 1+1;",
	}
	out := retry.DoWithRetry(
		t,
		"try mysql connection",
		10,
		5*time.Second,
		func() (string, error) {
			return k8s.RunKubectlAndGetOutputE(t, kubectlOptions, kubectlExecMysqlCommand...)
		},
	)
	resp := strings.Split(out, "\n")
	assert.Equal(t, resp[len(resp)-1], "2")
}

type RedisInfo struct {
	Endpoint string
	Port     string
}

// smokeTestRedis makes a SET/GET query over the redis protocol to the provided redis database.
func smokeTestRedis(t *testing.T, serverInfo RedisInfo) {
	connString := fmt.Sprintf(
		"%s:%s",
		serverInfo.Endpoint,
		serverInfo.Port,
	)
	client := redis.NewClient(&redis.Options{
		Addr:     connString,
		Password: "", // no password set
		DB:       0,  // use default DB
	})

	ctx := context.TODO()
	_, connErr := client.Ping(ctx).Result()
	require.NoError(t, connErr)
	defer client.Close()

	setErr := client.Set(ctx, "key", "foo", 0).Err()
	require.NoError(t, setErr)

	val, getErr := client.Get(ctx, "key").Result()
	require.NoError(t, getErr)
	require.Equal(t, val, "foo")
}

// Some of the tests need to run against Organization root account. This method overrides the default AWS_* environment variables
func configureTerraformForOrgTestAccount(t *testing.T, terraformOptions *terraform.Options) {
	if terraformOptions.EnvVars == nil {
		terraformOptions.EnvVars = map[string]string{}
	}
	terraformOptions.EnvVars["AWS_ACCESS_KEY_ID"] = os.Getenv("AWS_ORGTEST_ACCESS_KEY_ID")
	terraformOptions.EnvVars["AWS_SECRET_ACCESS_KEY"] = os.Getenv("AWS_ORGTEST_SECRET_ACCESS_KEY")
}

func pickNRegions(t *testing.T, count int) []string {
	regions := []string{}
	for i := 0; i < count; i++ {
		region := aws.GetRandomStableRegion(t, nil, regions)
		regions = append(regions, region)
	}
	return regions
}

// read the externalAccountId to use for saving RDS snapshots from the environment
func getExternalAccountId() string {
	return os.Getenv("TEST_EXTERNAL_ACCOUNT_ID")
}

func pickAwsRegion(t *testing.T) string {
	// At least one zone in us-west-2, sa-east-1, eu-north-1, ap-northeast-2 do not have t2.micro
	// ap-south-1 doesn't have ECS optimized Linux
	return aws.GetRandomStableRegion(t, []string{}, []string{"sa-east-1", "ap-south-1", "ap-northeast-2", "us-west-2", "eu-north-1"})
}

func createBaseTerraformOptions(t *testing.T, terraformDir string, awsRegion string) *terraform.Options {
	return &terraform.Options{
		TerraformDir: terraformDir,
		Vars: map[string]interface{}{
			"aws_region": awsRegion,
		},
		RetryableTerraformErrors: retryableTerraformErrors,
		MaxRetries:               maxTerraformRetries,
		TimeBetweenRetries:       sleepBetweenTerraformRetries,
	}
}

func testSSH(t *testing.T, ip string, sshUsername string, keyPair *aws.Ec2Keypair) {
	publicHost := ssh.Host{
		Hostname:    ip,
		SshUserName: sshUsername,
		SshKeyPair:  keyPair.KeyPair,
	}

	retry.DoWithRetry(
		t,
		fmt.Sprintf("SSH to public host %s", ip),
		10,
		30*time.Second,
		func() (string, error) {
			return "", ssh.CheckSshConnectionE(t, publicHost)
		},
	)
}
