# Python KISS Templates

Minimal OpenAPI Generator template overrides for:
- `pydantic` models (v2 style)
- `httpx` sync + async clients
- `pyproject.toml` packaging (PEP 621 + hatchling)
- modern typing syntax in generated code (`| None`, `list[...]`, `dict[...]`)
- very shallow call path (`API method -> ApiClient.request -> httpx`)

## Usage

Config source of truth is:
- [`openapi-generator.config.json`](/Users/sygmei/Projects/openapi-generator-kiss-templates/openapi-generator.config.json)
- Section: `languages.python`

`openapi-generator-cli` cannot directly read per-language sections, so Docker build extracts the Python section automatically.

Direct generation example (section extraction + generate):
```bash
python -c "import json,pathlib; cfg=json.loads(pathlib.Path('openapi-generator.config.json').read_text()); common=cfg.get('common',{}); lang=cfg['languages']['python']; merged={**{k:v for k,v in common.items() if k not in ('ignoreList','additionalProperties')}, **{k:v for k,v in lang.items() if k not in ('ignoreList','additionalProperties')}}; ap={**common.get('additionalProperties',{}), **lang.get('additionalProperties',{})}; merged.update({'additionalProperties': ap} if ap else {}); pathlib.Path('/tmp/oag-python-config.json').write_text(json.dumps(merged, indent=2))"
openapi-generator-cli generate -c /tmp/oag-python-config.json
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
From repo root (single unified Dockerfile):

```bash
docker build --target python -t kiss-openapi-python .
docker save kiss-openapi-python -o kiss-openapi-python.tar
source .venv/bin/activate
docker-tartare extract kiss-openapi-python.tar /out out --dir
```

Generated client is embedded in the image at `/out/python-client` and extracted to `out/python-client`.

## Notes
- These templates intentionally favor readability over feature completeness.
- Error handling is intentionally direct (`ApiError` with status/body).
- Serialization is intentionally simple (`model_dump(..., by_alias=True)` when available).
- Docker generation runs `pyupgrade --py310-plus`, `ruff check --fix` (unused imports + import sorting), and `ruff format` on generated Python files.
