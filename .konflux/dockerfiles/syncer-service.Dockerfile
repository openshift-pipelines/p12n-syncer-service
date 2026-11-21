ARG GO_BUILDER=registry.redhat.io/ubi9/go-toolset:latest@sha256:51eef2836e5223c41577757c30544fbfb3f0710f3436b70b82d2195e35fcb743
ARG UBI_RUNTIME=registry.access.redhat.com/ubi9/ubi-minimal:latest@sha256:08d4c70f1baf6537a0728656cf7942d561e74a35916509d205b6519861266352

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
    com.redhat.component="openshift-pipelines-syncer-service-rhel9-container" \
    cpe="cpe:/a:redhat:openshift_pipelines:1.23::el9" \
    description="Red Hat OpenShift Pipelines syncer-service syncer-service" \
    io.k8s.description="Red Hat OpenShift Pipelines syncer-service syncer-service" \
    io.k8s.display-name="Red Hat OpenShift Pipelines syncer-service syncer-service" \
    io.openshift.tags="tekton,openshift,syncer-service,syncer-service" \
    maintainer="pipelines-extcomm@redhat.com" \
    name="openshift-pipelines/pipelines-syncer-service-rhel9" \
    summary="Red Hat OpenShift Pipelines syncer-service syncer-service" \
    version="v1.23.5"

RUN microdnf install -y shadow-utils && \
    groupadd -r -g 65532 nonroot && useradd --no-log-init -r -u 65532 -g nonroot nonroot
USER 65532

ENTRYPOINT ["/workload-controller"]
