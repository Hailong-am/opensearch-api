# Multi-stage build: compile the opensearch-api plugin then install into OpenSearch
#
# Build:
#   docker build --build-arg OS_VERSION=3.7.0 -t opensearch-api:3.7.0 .
#
# Run:
#   docker run -d --name opensearch-api \
#     -p 9200:9200 -p 9600:9600 \
#     -e "discovery.type=single-node" \
#     -e "DISABLE_SECURITY_PLUGIN=true" \
#     opensearch-api:3.7.0
#
# Dump spec:
#   curl http://localhost:9200/_plugins/api | python3 -m json.tool

ARG OS_VERSION=3.7.0

# ──────────────────────────────────────────────
# Stage 1: Build the plugin
# ──────────────────────────────────────────────
FROM amazoncorretto:21-al2023 AS builder

ARG OS_VERSION

RUN dnf install -y git findutils && dnf clean all

WORKDIR /build
RUN git clone --depth 1 https://github.com/Hailong-am/opensearch-api.git .

RUN ./gradlew assemble \
    -Dopensearch.version=${OS_VERSION} \
    -Dbuild.snapshot=false \
    --no-daemon

# ──────────────────────────────────────────────
# Stage 2: OpenSearch with plugin installed
# ──────────────────────────────────────────────
FROM opensearchproject/opensearch:${OS_VERSION}

ARG OS_VERSION

COPY --from=builder /build/build/distributions/opensearch-api-${OS_VERSION}.0.zip /tmp/opensearch-api.zip

RUN /usr/share/opensearch/bin/opensearch-plugin install --batch file:///tmp/opensearch-api.zip

EXPOSE 9200 9600
