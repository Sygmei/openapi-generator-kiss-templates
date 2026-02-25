# Python KISS Templates

Minimal OpenAPI Generator template overrides for:
- `pydantic` models (v2 style)
- `httpx` sync client
- `pyproject.toml` packaging (PEP 621 + hatchling)
- very shallow call path (`API method -> ApiClient.request -> httpx`)

## Usage

```bash
openapi-generator-cli generate \
  -c /absolute/path/to/openapi-generator-kiss-templates/python/openapi-generator-config.yaml
```

## Docker Shortcut
From repo root:

```bash
docker build -t kiss-openapi-test .
docker run --rm -v "$PWD:/work" kiss-openapi-test
```

Generated files are written to `out/python-client` in this repo.

## Notes
- These templates intentionally favor readability over feature completeness.
- Error handling is intentionally direct (`ApiError` with status/body).
- Serialization is intentionally simple (`model_dump(..., by_alias=True)` when available).
