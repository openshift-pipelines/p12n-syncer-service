ARG GO_BUILDER=brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.24
ARG RUNTIME=registry.redhat.io/ubi9/ubi-minimal@sha256:759f5f42d9d6ce2a705e290b7fc549e2d2cd39312c4fa345f93c02e4abb8da95

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/openshift-pipelines/syncer-service
COPY upstream .
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat /tmp/HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/workload-controller \
    ./cmd/controller

FROM $RUNTIME
ARG VERSION=syncer-service-controller-main

WORKDIR /

# Copy the binary from builder stage
COPY --from=builder /tmp/workload-controller /workload-controller

LABEL \
    com.redhat.component="openshift-pipelines-syncer-service-rhel9-container" \
    name="openshift-pipelines/syncer-service-rhel9" \
    version=$VERSION \
    summary="Red Hat OpenShift Pipelines Syncer Service" \
    maintainer="pipelines-extcomm@redhat.com" \
    description="Red Hat OpenShift Pipelines Syncer Service" \
    io.k8s.display-name="Red Hat OpenShift Pipelines Syncer Service" \
    io.k8s.description="Red Hat OpenShift Pipelines Syncer Service" \
    io.openshift.tags="pipelines,tekton,openshift"

RUN microdnf install -y shadow-utils && \
    groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/workload-controller"]
