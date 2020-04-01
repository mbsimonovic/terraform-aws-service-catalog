package main

import (
	"github.com/gruntwork-io/gruntwork-cli/entrypoint"
)

func main() {
	entrypoint.HelpTextLineWidth = 120
	app := checkSkipEnvCli()
	entrypoint.RunApp(app)
}
