# openapi-generator-kiss-templates
Simple and stupid OpenAPI generator templates

## Templates
- `python/`: minimal Python client templates (`pydantic` models + `httpx` client + `pyproject.toml`)

## Build Artifact With Docker
Build:
```bash
docker build -t kiss-openapi-artifact .
```

Save image layers (contains generated client in `/out/python-client`):
```bash
docker save kiss-openapi-artifact -o kiss-openapi-artifact.tar
```

Extract `/out` with `docker-tartare` (installed in local `.venv`):
```bash
source .venv/bin/activate
python scripts/extract_out.py kiss-openapi-artifact.tar --output out
```

This image is generated at build time; no `docker run` step is required.
Generator options are read from [`python/openapi-generator-config.yaml`](/Users/sygmei/Projects/openapi-generator-kiss-templates/python/openapi-generator-config.yaml).
