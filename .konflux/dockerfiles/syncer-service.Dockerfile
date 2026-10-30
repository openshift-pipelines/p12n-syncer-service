ARG GO_BUILDER=registry.access.redhat.com/ubi10/go-toolset:latest@sha256:5d2ab83e88506afee6bcc909fdab425ab979725ab30d6ad43a02aaa77e2258ff
ARG UBI_RUNTIME=registry.access.redhat.com/ubi10/ubi-minimal:latest@sha256:ab67cd02caf8706e34a695a1432ebe965934f6128ec352a6c3f4048b43a4fb5e

FROM $GO_BUILDER AS builder

WORKDIR /go/src/github.com/openshift-pipelines/syncer-service
COPY upstream .
RUN set -e; for f in patches/*.patch; do echo ${f}; [[ -f ${f} ]] || continue; git apply ${f}; done
ENV GODEBUG="http2server=0"
ENV GOEXPERIMENT=strictfipsruntime
RUN CGO_ENABLED=1 go build -ldflags="-X 'knative.dev/pkg/changeset.rev=$(cat /tmp/HEAD)'" -mod=vendor -tags disable_gcp,strictfipsruntime -v -o /tmp/workload-controller \
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
