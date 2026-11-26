ARG GO_BUILDER=registry.access.redhat.com/ubi10/go-toolset:latest@sha256:b9f867772f02ef0c8167b1ac327b615c9c6b06be16f5a42ea322597633d1d25e
ARG UBI_RUNTIME=registry.access.redhat.com/ubi10/ubi-minimal:latest@sha256:d63890a635f8f19177bce1775f74f587a47f4456844f1392456c4e3673a48753

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/openshift-pipelines/syncer-service
COPY upstream .
COPY head /tmp/HEAD
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN CGO_ENABLED=1 go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat /tmp/HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime,http2legacy -v -o /tmp/workload-controller \
    ./cmd/controller

FROM $UBI_RUNTIME

WORKDIR /

# Copy the binary from builder stage
COPY --from=builder /tmp/workload-controller /workload-controller

LABEL \
    com.redhat.component="openshift-pipelines-syncer-service-rhel10-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:nightly::el10" \
    description="Red Hat OpenShift Pipelines syncer-service syncer-service" \
    io.k8s.description="Red Hat OpenShift Pipelines syncer-service syncer-service" \
    io.k8s.display-name="Red Hat OpenShift Pipelines syncer-service syncer-service" \
    io.openshift.tags="tekton,openshift,syncer-service,syncer-service" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-syncer-service-rhel10" \
    summary="Red Hat OpenShift Pipelines syncer-service syncer-service" \
    version="nightly"

RUN microdnf install -y shadow-utils && \
    groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/workload-controller"]
