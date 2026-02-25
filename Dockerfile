FROM python:3.12-slim AS builder

ARG OPENAPI_GENERATOR_VERSION=7.12.0

RUN apt-get update \
  && apt-get install -y --no-install-recommends openjdk-21-jre-headless curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/openapi-generator \
  && curl -fsSL "https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/${OPENAPI_GENERATOR_VERSION}/openapi-generator-cli-${OPENAPI_GENERATOR_VERSION}.jar" \
    -o /opt/openapi-generator/openapi-generator-cli.jar

RUN python -m pip install --no-cache-dir pyupgrade ruff

WORKDIR /src
COPY . /src

ENV OPENAPI_CLI_JAR=/opt/openapi-generator/openapi-generator-cli.jar
ENV CONFIG_FILE=/src/python/openapi-generator-config.yaml
ENV OUT_DIR=/src/out/python-client
ENV OAG_IGNORE_LIST=.travis.yml,.gitlab-ci.yml,git_push.sh,setup.py,requirements.txt,tox.ini,setup.cfg,.github/,.openapi-generator/,docs/,test/,test-requirements.txt,**/rest.py,**/api_response.py

RUN set -euo pipefail; \
    rm -rf "$OUT_DIR"; \
    java -jar "$OPENAPI_CLI_JAR" generate -c "$CONFIG_FILE" --openapi-generator-ignore-list "$OAG_IGNORE_LIST"; \
    rm -rf "$OUT_DIR/.openapi-generator"; \
    find "$OUT_DIR" -type f -name "*.py" -print0 | xargs -0 -r pyupgrade --py310-plus --exit-zero-even-if-changed; \
    ruff check --fix "$OUT_DIR"; \
    ruff format "$OUT_DIR"; \
    python -m pip install --no-cache-dir "$OUT_DIR"; \
    python -c "import importlib,tomllib,pathlib; p=pathlib.Path('${OUT_DIR}/pyproject.toml'); d=tomllib.loads(p.read_text()); pkg=d['tool']['hatch']['build']['targets']['wheel']['packages'][0]; mod=importlib.import_module(pkg); print('Import OK:', mod.__name__)"

FROM scratch
COPY --from=builder /src/out/python-client /out/python-client
