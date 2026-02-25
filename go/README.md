# Go KISS Templates

Minimal OpenAPI Generator setup for a Go client (`go` generator).

## Usage

Config source of truth is:
- [`openapi-generator.config.json`](/Users/sygmei/Projects/openapi-generator-kiss-templates/openapi-generator.config.json)
- Section: `languages.go`

`openapi-generator-cli` cannot directly read per-language sections, so Docker build extracts the Go section automatically.

Direct generation example (section extraction + generate):
```bash
python3 -c "import json,pathlib; cfg=json.loads(pathlib.Path('openapi-generator.config.json').read_text()); common=cfg.get('common',{}); lang=cfg['languages']['go']; merged={**{k:v for k,v in common.items() if k not in ('ignoreList','additionalProperties')}, **{k:v for k,v in lang.items() if k not in ('ignoreList','additionalProperties')}}; ap={**common.get('additionalProperties',{}), **lang.get('additionalProperties',{})}; merged.update({'additionalProperties': ap} if ap else {}); pathlib.Path('/tmp/oag-go-config.json').write_text(json.dumps(merged, indent=2))"
openapi-generator-cli generate -c /tmp/oag-go-config.json
```

## Docker Shortcut

From repo root:

```bash
docker build -f Dockerfile.go -t kiss-openapi-go .
docker save kiss-openapi-go -o kiss-openapi-go.tar
source .venv/bin/activate
docker-tartare extract kiss-openapi-go.tar /out out --dir
```

Generated client is embedded in the image at `/out/go-client` and extracted to `out/go-client`.
