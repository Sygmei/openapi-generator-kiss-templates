ARG OPENAPI_GENERATOR_VERSION=7.12.0
ARG PACKAGE_VERSION=
ARG PYTHON_PACKAGE_VERSION=
ARG TYPESCRIPT_NPM_VERSION=
ARG GO_PACKAGE_VERSION=

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
# STAGE: CONFIG SPLITTER
# Purpose: split unified config into per-language artifacts once
########################################################################
FROM python:3.12-slim AS config-splitter
ARG PACKAGE_VERSION
ARG PYTHON_PACKAGE_VERSION
ARG TYPESCRIPT_NPM_VERSION
ARG GO_PACKAGE_VERSION

WORKDIR /src
COPY openapi-generator.config.json /src/openapi-generator.config.json
COPY scripts/split_openapi_config.py /usr/local/bin/split_openapi_config.py

RUN set -eu; \
    python /usr/local/bin/split_openapi_config.py \
      --config /src/openapi-generator.config.json \
      --out-root /out/config \
      --package-version "${PACKAGE_VERSION}" \
      --python-package-version "${PYTHON_PACKAGE_VERSION}" \
      --typescript-npm-version "${TYPESCRIPT_NPM_VERSION}" \
      --go-package-version "${GO_PACKAGE_VERSION}"

########################################################################
# STAGE: PYTHON BUILDER
# Purpose: generate Python client, run pyupgrade/ruff
########################################################################
FROM python:3.12-slim AS python-builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends openjdk-21-jre-headless \
  && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir pyupgrade ruff

COPY --from=openapi-cli /opt/openapi-generator/openapi-generator-cli.jar /opt/openapi-generator/openapi-generator-cli.jar

WORKDIR /src
COPY . /src

COPY --from=config-splitter /out/config/python/openapi-generator-config.json /tmp/openapi-generator-config.json
COPY --from=config-splitter /out/config/python/openapi-generator-ignore-list.txt /tmp/openapi-generator-ignore-list.txt
COPY --from=config-splitter /out/config/python/openapi-generator-out-dir.txt /tmp/openapi-generator-out-dir.txt

ENV OPENAPI_CLI_JAR=/opt/openapi-generator/openapi-generator-cli.jar

RUN set -eu; \
    OUT_DIR="$(cat /tmp/openapi-generator-out-dir.txt)"; \
    OAG_IGNORE_LIST="$(cat /tmp/openapi-generator-ignore-list.txt)"; \
    rm -rf "$OUT_DIR"; \
    java -jar "$OPENAPI_CLI_JAR" generate -c /tmp/openapi-generator-config.json --openapi-generator-ignore-list "$OAG_IGNORE_LIST"; \
    rm -rf "$OUT_DIR/.openapi-generator"; \
    find "$OUT_DIR" -type f -name "*.py" -print0 | xargs -0 -r pyupgrade --py310-plus --exit-zero-even-if-changed; \
    ruff check --fix "$OUT_DIR"; \
    ruff format "$OUT_DIR"; \
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
# Purpose: generate TypeScript client
########################################################################
FROM node:22-bookworm-slim AS typescript-builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends openjdk-17-jre-headless \
  && rm -rf /var/lib/apt/lists/*

COPY --from=openapi-cli /opt/openapi-generator/openapi-generator-cli.jar /opt/openapi-generator/openapi-generator-cli.jar

WORKDIR /src
COPY . /src

COPY --from=config-splitter /out/config/typescript/openapi-generator-config.json /tmp/openapi-generator-config.json
COPY --from=config-splitter /out/config/typescript/openapi-generator-ignore-list.txt /tmp/openapi-generator-ignore-list.txt
COPY --from=config-splitter /out/config/typescript/openapi-generator-out-dir.txt /tmp/openapi-generator-out-dir.txt

ENV OPENAPI_CLI_JAR=/opt/openapi-generator/openapi-generator-cli.jar

RUN set -eu; \
    OUT_DIR="$(cat /tmp/openapi-generator-out-dir.txt)"; \
    OAG_IGNORE_LIST="$(cat /tmp/openapi-generator-ignore-list.txt)"; \
    rm -rf "$OUT_DIR"; \
    java -jar "$OPENAPI_CLI_JAR" generate -c /tmp/openapi-generator-config.json --openapi-generator-ignore-list "$OAG_IGNORE_LIST"; \
    rm -rf "$OUT_DIR/.openapi-generator"; \
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
# Purpose: generate Go client
########################################################################
FROM golang:1.24-bookworm AS go-builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends openjdk-17-jre-headless python3-minimal \
  && rm -rf /var/lib/apt/lists/*

COPY --from=openapi-cli /opt/openapi-generator/openapi-generator-cli.jar /opt/openapi-generator/openapi-generator-cli.jar

WORKDIR /src
COPY . /src

COPY --from=config-splitter /out/config/go/openapi-generator-config.json /tmp/openapi-generator-config.json
COPY --from=config-splitter /out/config/go/openapi-generator-ignore-list.txt /tmp/openapi-generator-ignore-list.txt
COPY --from=config-splitter /out/config/go/openapi-generator-out-dir.txt /tmp/openapi-generator-out-dir.txt

ENV OPENAPI_CLI_JAR=/opt/openapi-generator/openapi-generator-cli.jar

RUN set -eu; \
    OUT_DIR="$(cat /tmp/openapi-generator-out-dir.txt)"; \
    OAG_IGNORE_LIST="$(cat /tmp/openapi-generator-ignore-list.txt)"; \
    rm -rf "$OUT_DIR"; \
    java -jar "$OPENAPI_CLI_JAR" generate -c /tmp/openapi-generator-config.json --openapi-generator-ignore-list "$OAG_IGNORE_LIST"; \
    rm -rf "$OUT_DIR/.openapi-generator"; \
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
