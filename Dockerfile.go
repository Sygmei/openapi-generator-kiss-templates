FROM golang:1.24-bookworm AS builder

ARG OPENAPI_GENERATOR_VERSION=7.12.0

RUN apt-get update \
  && apt-get install -y --no-install-recommends openjdk-17-jre-headless curl ca-certificates python3-minimal \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/openapi-generator \
  && curl -fsSL "https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/${OPENAPI_GENERATOR_VERSION}/openapi-generator-cli-${OPENAPI_GENERATOR_VERSION}.jar" \
    -o /opt/openapi-generator/openapi-generator-cli.jar

WORKDIR /src
COPY . /src

ENV OPENAPI_CLI_JAR=/opt/openapi-generator/openapi-generator-cli.jar
ENV UNIFIED_CONFIG_FILE=/src/openapi-generator.config.json

RUN set -eu; \
    python3 -c "import json,pathlib; cfg=json.loads(pathlib.Path('${UNIFIED_CONFIG_FILE}').read_text()); common=cfg.get('common', {}); lang=cfg['languages']['go']; merged={**{k:v for k,v in common.items() if k not in ('ignoreList','additionalProperties')}, **{k:v for k,v in lang.items() if k not in ('ignoreList','additionalProperties')}}; additional={**common.get('additionalProperties', {}), **lang.get('additionalProperties', {})}; merged.update({'additionalProperties': additional} if additional else {}); pathlib.Path('/tmp/openapi-generator-config.json').write_text(json.dumps(merged, indent=2)); ignore=[*common.get('ignoreList', []), *lang.get('ignoreList', [])]; pathlib.Path('/tmp/openapi-generator-ignore-list.txt').write_text(','.join(ignore)); out=merged.get('outputDir', 'out/go-client'); out=f'/src/{out}' if not out.startswith('/') else out; pathlib.Path('/tmp/openapi-generator-out-dir.txt').write_text(out)"; \
    OUT_DIR="$(cat /tmp/openapi-generator-out-dir.txt)"; \
    OAG_IGNORE_LIST="$(cat /tmp/openapi-generator-ignore-list.txt)"; \
    rm -rf "$OUT_DIR"; \
    java -jar "$OPENAPI_CLI_JAR" generate -c /tmp/openapi-generator-config.json --openapi-generator-ignore-list "$OAG_IGNORE_LIST"; \
    rm -rf "$OUT_DIR/.openapi-generator"; \
    test -f "$OUT_DIR/go.mod"; \
    grep -E '^module ' "$OUT_DIR/go.mod"

FROM scratch
COPY --from=builder /src/out/go-client /out/go-client
