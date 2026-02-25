# Python KISS Templates

Minimal OpenAPI Generator template overrides for:
- `pydantic` models (v2 style)
- `httpx` sync + async clients
- `pyproject.toml` packaging (PEP 621 + hatchling)
- modern typing syntax in generated code (`| None`, `list[...]`, `dict[...]`)
- very shallow call path (`API method -> ApiClient.request -> httpx`)

## Usage

```bash
openapi-generator-cli generate \
  -c /absolute/path/to/openapi-generator-kiss-templates/python/openapi-generator-config.yaml
```

Sync high-level client:
```python
from your_package_name import Client

client = Client()
client.ingredients.some_operation(...)
```

Async high-level client:
```python
from your_package_name import AsyncClient

async with AsyncClient() as client:
    await client.ingredients.some_operation(...)
```

## Docker Shortcut
From repo root:

```bash
docker build -t kiss-openapi-artifact .
docker save kiss-openapi-artifact -o kiss-openapi-artifact.tar
source .venv/bin/activate
python scripts/extract_out.py kiss-openapi-artifact.tar --output out
```

Generated client is embedded in the image at `/out/python-client` and extracted to `out/python-client`.

## Notes
- These templates intentionally favor readability over feature completeness.
- Error handling is intentionally direct (`ApiError` with status/body).
- Serialization is intentionally simple (`model_dump(..., by_alias=True)` when available).
- Docker generation runs `pyupgrade --py310-plus`, `ruff check --fix` (unused imports + import sorting), and `ruff format` on generated Python files.
