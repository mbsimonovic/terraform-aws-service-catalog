package data_stores

import (
	"database/sql"
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/stretchr/testify/assert"
)

type RDSInfo struct {
	Username   string
	Password   string
	DBName     string
	DBEndpoint string
	DBPort     string
}

// SmokeTestMysql makes a "SELECT 1+1" query over the mysql protocol to the provided RDS database.
func SmokeTestMysql(t *testing.T, serverInfo RDSInfo) {
	result := retry.DoWithRetry(
		t,
		"connect to mysql",
		// Try 10 times, 30 seconds apart. The most common failure here is an out of memory issue, so when we run into
		// it, we want to space out the calls so that they don't overlap with other terraform calls happening.
		10,
		30*time.Second,
		func() (string, error) {
			dbConnString := fmt.Sprintf(
				"%s:%s@tcp(%s:%s)/%s",
				serverInfo.Username,
				serverInfo.Password,
				serverInfo.DBEndpoint,
				serverInfo.DBPort,
				serverInfo.DBName,
			)
			db, connErr := sql.Open("mysql", dbConnString)
			if connErr != nil {
				return "", connErr
			}
			defer db.Close()

			row := db.QueryRow("SELECT 1+1;")
			var result string
			scanErr := row.Scan(&result)
			if scanErr != nil {
				return "", scanErr
			}
			return result, nil
		},
	)
	assert.Equal(t, "2", result)
}
