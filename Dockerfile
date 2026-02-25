ARG OPENAPI_GENERATOR_VERSION=7.12.0

########################################################################
# STAGE: OPENAPI CLI DOWNLOAD
# Purpose: download and cache openapi-generator-cli.jar once
########################################################################
FROM debian:bookworm-slim AS openapi-cli
ARG OPENAPI_GENERATOR_VERSION

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/openapi-generator \
  && curl -fsSL "https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/${OPENAPI_GENERATOR_VERSION}/openapi-generator-cli-${OPENAPI_GENERATOR_VERSION}.jar" \
    -o /opt/openapi-generator/openapi-generator-cli.jar

########################################################################
# STAGE: PYTHON BUILDER
# Purpose: generate Python client, run pyupgrade/ruff, validate import
########################################################################
FROM python:3.12-slim AS python-builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends openjdk-21-jre-headless \
  && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir pyupgrade ruff

COPY --from=openapi-cli /opt/openapi-generator/openapi-generator-cli.jar /opt/openapi-generator/openapi-generator-cli.jar

WORKDIR /src
COPY . /src

ENV OPENAPI_CLI_JAR=/opt/openapi-generator/openapi-generator-cli.jar
ENV UNIFIED_CONFIG_FILE=/src/openapi-generator.config.json

RUN set -euo pipefail; \
    python -c "import json,pathlib; cfg=json.loads(pathlib.Path('${UNIFIED_CONFIG_FILE}').read_text()); common=cfg.get('common', {}); lang=cfg['languages']['python']; merged={**{k:v for k,v in common.items() if k not in ('ignoreList','additionalProperties')}, **{k:v for k,v in lang.items() if k not in ('ignoreList','additionalProperties')}}; additional={**common.get('additionalProperties', {}), **lang.get('additionalProperties', {})}; merged.update({'additionalProperties': additional} if additional else {}); pathlib.Path('/tmp/openapi-generator-config.json').write_text(json.dumps(merged, indent=2)); ignore=[*common.get('ignoreList', []), *lang.get('ignoreList', [])]; pathlib.Path('/tmp/openapi-generator-ignore-list.txt').write_text(','.join(ignore)); out=merged.get('outputDir', 'out/python-client'); out=f'/src/{out}' if not out.startswith('/') else out; pathlib.Path('/tmp/openapi-generator-out-dir.txt').write_text(out)"; \
    OUT_DIR="$(cat /tmp/openapi-generator-out-dir.txt)"; \
    OAG_IGNORE_LIST="$(cat /tmp/openapi-generator-ignore-list.txt)"; \
    rm -rf "$OUT_DIR"; \
    java -jar "$OPENAPI_CLI_JAR" generate -c /tmp/openapi-generator-config.json --openapi-generator-ignore-list "$OAG_IGNORE_LIST"; \
    rm -rf "$OUT_DIR/.openapi-generator"; \
    find "$OUT_DIR" -type f -name "*.py" -print0 | xargs -0 -r pyupgrade --py310-plus --exit-zero-even-if-changed; \
    ruff check --fix "$OUT_DIR"; \
    ruff format "$OUT_DIR"; \
    python -m pip install --no-cache-dir "$OUT_DIR"; \
    python -c "import importlib,tomllib,pathlib; p=pathlib.Path('${OUT_DIR}/pyproject.toml'); d=tomllib.loads(p.read_text()); pkg=d['tool']['hatch']['build']['targets']['wheel']['packages'][0]; mod=importlib.import_module(pkg); print('Import OK:', mod.__name__)"; \
    rm -rf /out/python-client; \
    mkdir -p /out; \
    cp -R "$OUT_DIR" /out/python-client

########################################################################
# STAGE: PYTHON ARTIFACT
# Purpose: expose only /out/python-client
########################################################################
FROM scratch AS python
COPY --from=python-builder /out/python-client /out/python-client

########################################################################
# STAGE: TYPESCRIPT BUILDER
# Purpose: generate TypeScript client and validate package.json
########################################################################
FROM node:22-bookworm-slim AS typescript-builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends openjdk-17-jre-headless \
  && rm -rf /var/lib/apt/lists/*

COPY --from=openapi-cli /opt/openapi-generator/openapi-generator-cli.jar /opt/openapi-generator/openapi-generator-cli.jar

WORKDIR /src
COPY . /src

ENV OPENAPI_CLI_JAR=/opt/openapi-generator/openapi-generator-cli.jar
ENV UNIFIED_CONFIG_FILE=/src/openapi-generator.config.json

RUN set -eu; \
    node -e "const fs=require('fs'); const cfg=JSON.parse(fs.readFileSync(process.env.UNIFIED_CONFIG_FILE, 'utf8')); const common=cfg.common || {}; const lang=(cfg.languages || {}).typescript; if (!lang) { throw new Error('Missing languages.typescript in unified config'); } const strip=(obj)=>Object.fromEntries(Object.entries(obj).filter(([k])=>k!=='ignoreList'&&k!=='additionalProperties')); const merged={...strip(common), ...strip(lang)}; const additional={...(common.additionalProperties || {}), ...(lang.additionalProperties || {})}; if (Object.keys(additional).length) merged.additionalProperties=additional; fs.writeFileSync('/tmp/openapi-generator-config.json', JSON.stringify(merged, null, 2)); const ignore=[...(common.ignoreList || []), ...(lang.ignoreList || [])]; fs.writeFileSync('/tmp/openapi-generator-ignore-list.txt', ignore.join(',')); let out=merged.outputDir || 'out/typescript-client'; if (!out.startsWith('/')) out='/src/' + out; fs.writeFileSync('/tmp/openapi-generator-out-dir.txt', out);"; \
    OUT_DIR="$(cat /tmp/openapi-generator-out-dir.txt)"; \
    OAG_IGNORE_LIST="$(cat /tmp/openapi-generator-ignore-list.txt)"; \
    rm -rf "$OUT_DIR"; \
    java -jar "$OPENAPI_CLI_JAR" generate -c /tmp/openapi-generator-config.json --openapi-generator-ignore-list "$OAG_IGNORE_LIST"; \
    rm -rf "$OUT_DIR/.openapi-generator"; \
    node -e "const p=require('${OUT_DIR}/package.json'); console.log('Package OK:', p.name);"; \
    rm -rf /out/typescript-client; \
    mkdir -p /out; \
    cp -R "$OUT_DIR" /out/typescript-client

########################################################################
# STAGE: TYPESCRIPT ARTIFACT
# Purpose: expose only /out/typescript-client
########################################################################
FROM scratch AS typescript
COPY --from=typescript-builder /out/typescript-client /out/typescript-client

########################################################################
# STAGE: GO BUILDER
# Purpose: generate Go client and validate go.mod
########################################################################
FROM golang:1.24-bookworm AS go-builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends openjdk-17-jre-headless python3-minimal \
  && rm -rf /var/lib/apt/lists/*

COPY --from=openapi-cli /opt/openapi-generator/openapi-generator-cli.jar /opt/openapi-generator/openapi-generator-cli.jar

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
    grep -E '^module ' "$OUT_DIR/go.mod"; \
    rm -rf /out/go-client; \
    mkdir -p /out; \
    cp -R "$OUT_DIR" /out/go-client

########################################################################
# STAGE: GO ARTIFACT
# Purpose: expose only /out/go-client
########################################################################
FROM scratch AS go
COPY --from=go-builder /out/go-client /out/go-client

########################################################################
# STAGE: ALL ARTIFACTS (DEFAULT FINAL STAGE)
# Purpose: expose all generated clients under /out
########################################################################
FROM scratch AS all
COPY --from=python-builder /out/python-client /out/python-client
COPY --from=typescript-builder /out/typescript-client /out/typescript-client
COPY --from=go-builder /out/go-client /out/go-client
