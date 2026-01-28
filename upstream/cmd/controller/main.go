package main

import (
	"github.com/openshift-pipelines/syncer-service/pkg/reconciler"

	"knative.dev/pkg/injection/sharedmain"
)

func main() {
	sharedmain.Main("syncer-service", reconciler.NewController())
}
