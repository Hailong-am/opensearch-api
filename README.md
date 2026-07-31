# opensearch-api

An OpenSearch plugin that exposes a live OpenAPI specification of all registered REST endpoints via `GET /_plugins/api`.

This fork adds support for **OpenSearch 3.x** (3.7.0+). The upstream plugin at [dblock/opensearch-api](https://github.com/dblock/opensearch-api) targets 2.x.

## What It Does

Once installed, the plugin adds a single endpoint:

```
GET /_plugins/api
```

Returns an OpenAPI 3.0.1 specification dynamically generated from all REST handlers currently registered in the cluster -- including every installed plugin. This is the authoritative source of truth for what APIs a running cluster actually exposes.

## Quick Start (Docker)

The fastest way to get a running cluster with the plugin:

```bash
# Build the image (takes ~3 min on first run, downloads Gradle + dependencies)
docker build --build-arg OS_VERSION=3.7.0 -t opensearch-api:3.7.0 .

# Run
docker run -d --name opensearch-api \
  -p 9200:9200 \
  -e "discovery.type=single-node" \
  -e "DISABLE_SECURITY_PLUGIN=true" \
  opensearch-api:3.7.0

# Wait for startup (~20s), then dump the spec
sleep 20
curl http://localhost:9200/_plugins/api | python3 -m json.tool > opensearch-openapi-cluster.json

# Check endpoint count
python3 -c "
import json
spec = json.load(open('opensearch-openapi-cluster.json'))
total = sum(len([m for m in v if m.upper() in ('GET','POST','PUT','DELETE','PATCH','HEAD')])
           for v in spec['paths'].values())
print(f'Paths: {len(spec[\"paths\"])}, Endpoints: {total}')
"
```

Expected output: `Paths: 733, Endpoints: 1114`

### Using docker-compose

```bash
docker compose up -d
sleep 20
curl http://localhost:9200/_plugins/api | python3 -m json.tool
```

## Use with dump-cluster-spec Tool

The [opensearch-api-specification](https://github.com/opensearch-project/opensearch-api-specification) project has a tool that formats the raw output into a proper YAML spec file:

```bash
git clone https://github.com/opensearch-project/opensearch-api-specification.git
cd opensearch-api-specification
npm install

# Start the cluster first (see Quick Start above), then:
npm run dump-cluster-spec -- \
  --opensearch-url http://localhost:9200 \
  --output opensearch-cluster-spec.yaml

wc -l opensearch-cluster-spec.yaml   # ~1800 lines
```

## Building from Source

Requires JDK 21+ and internet access for Gradle/Maven downloads.

```bash
git clone https://github.com/Hailong-am/opensearch-api.git
cd opensearch-api

# Build and test (tests spin up an embedded cluster automatically)
./gradlew build -Dopensearch.version=3.7.0 -Dbuild.snapshot=false --no-daemon

# Plugin zip location:
# build/distributions/opensearch-api-3.7.0.0.zip
```

### Installing into an Existing Cluster

```bash
# Option A: from local build
/path/to/opensearch/bin/opensearch-plugin install --batch \
  file:///path/to/opensearch-api-3.7.0.0.zip

# Option B: restart after install
bin/opensearch-plugin install --batch file:///tmp/opensearch-api-3.7.0.0.zip
# then restart OpenSearch
```

### Verifying Installation

```bash
# Check plugin is listed
curl http://localhost:9200/_cat/plugins?h=component | grep opensearch-api

# Hit the API endpoint
curl http://localhost:9200/_plugins/api | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('OpenAPI:', d['openapi'])
print('Paths:', len(d['paths']))
"
```

## Sample Output

```json
{
  "openapi": "3.0.1",
  "info": {
    "title": "opensearch",
    "version": "3.7.0",
    "description": "The OpenSearch Project: https://opensearch.org/"
  },
  "paths": {
    "/_plugins/_ml/models/{model_id}/_predict": {
      "post": { ... }
    },
    "/_plugins/_alerting/monitors": {
      "get": { ... },
      "post": { ... }
    },
    ...
  }
}
```

## Comparing with Published OpenAPI Spec

The published [opensearch-openapi.yaml](https://github.com/opensearch-project/opensearch-api-specification/releases/download/main-latest/opensearch-openapi.yaml) (v2.16.0) covers ~328 plugin endpoints. The live cluster dump returns **498 plugin endpoints** -- the spec is significantly behind the implementation. Key gaps:

| Plugin | Endpoints missing from spec |
|--------|---------------------------|
| `/_plugins/_security_analytics` | 43 |
| `/_plugins/_alerting` | 39 |
| `/_plugins/_anomaly_detection` | 37 |
| `/_plugins/_forecast` | 26 (entire plugin) |
| `/_plugins/_ml` | 25 |
| Others | 89 |

See [OpenSearch API Gap Analysis](https://chorus.aws.dev/doc/s9p8rWImROUB) for the full comparison.

## Changes from Upstream

This fork adds OpenSearch 3.x compatibility:

| Change | Reason |
|--------|--------|
| `repositories.gradle`: added `ci.opensearch.org/maven2/` | `build-tools` 3.7.0 release only available from OpenSearch CI |
| `build.gradle`: Gradle 9.4.1+ wrapper | `build-tools` 3.7.0 requires Gradle 9.4.1+ |
| `build.gradle`: `java.targetCompatibility = VERSION_21` | OpenSearch 3.x requires JVM 21 |
| `src/**/*.java`: `transport.client.node.NodeClient` | Package moved in OpenSearch 3.x |
| `build.gradle`: `apply plugin: 'opensearch.java-agent'` | OpenSearch 3.x test framework requires security agent |
| `Dockerfile` + `docker-compose.yml` | Easy local usage |

## License

Apache 2.0
