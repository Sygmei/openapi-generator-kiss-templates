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
# STAGE: CONFIG SPLITTER
# Purpose: split unified config into per-language artifacts once
########################################################################
FROM python:3.12-slim AS config-splitter

WORKDIR /src
COPY openapi-generator.config.json /src/openapi-generator.config.json

RUN set -euo pipefail; \
    python <<'PY'
import json
from pathlib import Path

cfg = json.loads(Path("/src/openapi-generator.config.json").read_text())
common = cfg.get("common", {})
languages = cfg.get("languages", {})

defaults = {
    "python": "out/python-client",
    "typescript": "out/typescript-client",
    "go": "out/go-client",
}


def strip_special(values: dict) -> dict:
    return {
        k: v
        for k, v in values.items()
        if k not in ("ignoreList", "additionalProperties")
    }


out_root = Path("/out/config")
for language, default_out in defaults.items():
    if language not in languages:
        raise KeyError(f"Missing languages.{language} in unified config")

    lang = languages[language]
    merged = {**strip_special(common), **strip_special(lang)}

    additional = {
        **common.get("additionalProperties", {}),
        **lang.get("additionalProperties", {}),
    }
    if additional:
        merged["additionalProperties"] = additional

    lang_dir = out_root / language
    lang_dir.mkdir(parents=True, exist_ok=True)
    (lang_dir / "openapi-generator-config.json").write_text(
        json.dumps(merged, indent=2)
    )

    ignore = [*common.get("ignoreList", []), *lang.get("ignoreList", [])]
    (lang_dir / "openapi-generator-ignore-list.txt").write_text(",".join(ignore))

    out_dir = merged.get("outputDir", default_out)
    if not out_dir.startswith("/"):
        out_dir = f"/src/{out_dir}"
    (lang_dir / "openapi-generator-out-dir.txt").write_text(out_dir)
PY

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

RUN set -euo pipefail; \
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
