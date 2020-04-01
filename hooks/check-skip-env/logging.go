package main

import (
	"github.com/gruntwork-io/gruntwork-cli/logging"
	"github.com/sirupsen/logrus"
)

func getProjectLogger() *logrus.Entry {
	logger := logging.GetLogger("")
	return logger.WithField("name", "check-skip-env")
}
