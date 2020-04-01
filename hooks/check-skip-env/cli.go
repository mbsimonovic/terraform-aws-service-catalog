package main

import (
	"os"

	"github.com/gruntwork-io/gruntwork-cli/entrypoint"
	"github.com/gruntwork-io/gruntwork-cli/errors"
	"github.com/gruntwork-io/gruntwork-cli/logging"
	"github.com/sirupsen/logrus"
	"github.com/urfave/cli"
)

const customUsageText = `Usage: check-skip-env [--help] [--log-level=info] FILE FILE ...

A CLI for checking to make sure no uncommented os.Setenv calls are committed in test golang files. Each positional
argument should be a golang source file.

Options:
   --log-level LEVEL  Set the log level to LEVEL. Must be one of: [panic fatal error warning info debug]
                      (default: "info")
   --help, -h         show help
`

var (
	logLevelFlag = cli.StringFlag{
		Name:  "loglevel",
		Value: logrus.InfoLevel.String(),
	}
)

// initCli initializes the CLI app before any command is actually executed. This function will handle all the setup
// code, such as setting up the logger with the appropriate log level.
func initCli(cliContext *cli.Context) error {
	// Set logging level
	logLevel := cliContext.String(logLevelFlag.Name)
	level, err := logrus.ParseLevel(logLevel)
	if err != nil {
		return errors.WithStackTrace(err)
	}
	logging.SetGlobalLogLevel(level)

	// If logging level is for debugging (debug or trace), enable stacktrace debugging
	if level == logrus.DebugLevel || level == logrus.TraceLevel {
		os.Setenv("GRUNTWORK_DEBUG", "true")
	}
	return nil
}

// cliAction is the main routine of the CLI. This will check all the files that are passed in, searching for uncommented
// os.Setenv calls that correspond to setting terratest SKIP environment variables. If it finds any files, this command
// will error out.
func cliAction(ctx *cli.Context) error {
	projectLogger := getProjectLogger()

	filesWithSkipEnvSet := []string{}
	for _, arg := range ctx.Args() {
		projectLogger.Infof("Checking file %s", arg)
		hasSkipEnvSetCall, err := hasAnySkipEnvSetCalls(arg)
		if err != nil {
			return err
		}
		if hasSkipEnvSetCall {
			filesWithSkipEnvSet = append(filesWithSkipEnvSet, arg)
		}
	}

	if len(filesWithSkipEnvSet) > 0 {
		projectLogger.Error("Found files with os.Setenv calls setting terratest SKIP environment variables.")
		for _, file := range filesWithSkipEnvSet {
			projectLogger.Errorf("\t- %s", file)
		}
		return FailedCheck{}
	}
	return nil
}

// checkSkipEnvCli constructs the CLI app for this command.
func checkSkipEnvCli() *cli.App {
	app := entrypoint.NewApp()
	cli.AppHelpTemplate = customUsageText

	app.Name = "check-skip-env"
	app.Author = "Gruntwork <www.gruntwork.io>"
	app.Description = "A CLI for checking to make sure no uncommented os.Setenv calls are committed in test golang files."
	app.EnableBashCompletion = true

	app.Before = initCli
	app.Action = cliAction

	app.Flags = []cli.Flag{
		logLevelFlag,
	}
	return app
}

// FailedCheck is an error that is returned when the check that this CLI is making fails
type FailedCheck struct{}

func (err FailedCheck) Error() string {
	return "Failed skip environment check"
}
