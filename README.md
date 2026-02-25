# openapi-generator-kiss-templates
Simple and stupid OpenAPI generator templates

## Templates
- `python/`: minimal Python client templates (`pydantic` models + `httpx` client + `pyproject.toml`)

## Test With Docker
Build:
```bash
docker build -t kiss-openapi-test .
```

Run template generation + install/import smoke test:
```bash
docker run --rm -v "$PWD:/work" kiss-openapi-test
```

Generated files are written to `out/python-client` in this repo.
Generator options are read from [`python/openapi-generator-config.yaml`](/Users/sygmei/Projects/openapi-generator-kiss-templates/python/openapi-generator-config.yaml).
