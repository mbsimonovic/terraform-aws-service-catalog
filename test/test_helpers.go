package test

import (
	"database/sql"
	"fmt"
	"os"
	"testing"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

// Test constants for the Gruntwork Phx DevOps account
const (
	baseDomainForTest = "gruntwork.in"
	acmDomainForTest  = "*.gruntwork.in"
)

// Regions in Gruntwork Phx DevOps account that have ACM certs
var acmRegionsForTest = []string{
	"us-east-1",
	"us-east-2",
	"us-west-1",
	"us-west-2",
	"eu-west-1",
	"eu-central-1",
	"ap-northeast-1",
	"ap-southeast-2",
	"ca-central-1",
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
