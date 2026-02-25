# TypeScript KISS Templates

Minimal OpenAPI Generator setup for a TypeScript client (`typescript-fetch`).

## Usage

Config source of truth is:
- [`openapi-generator.config.json`](/Users/sygmei/Projects/openapi-generator-kiss-templates/openapi-generator.config.json)
- Section: `languages.typescript`

`openapi-generator-cli` cannot directly read per-language sections, so Docker build extracts the TypeScript section automatically.

Direct generation example (section extraction + generate):
```bash
node -e "const fs=require('fs'); const cfg=JSON.parse(fs.readFileSync('openapi-generator.config.json','utf8')); const common=cfg.common||{}; const lang=cfg.languages.typescript; const strip=(obj)=>Object.fromEntries(Object.entries(obj).filter(([k])=>k!=='ignoreList'&&k!=='additionalProperties')); const merged={...strip(common), ...strip(lang)}; const ap={...(common.additionalProperties||{}), ...(lang.additionalProperties||{})}; if(Object.keys(ap).length) merged.additionalProperties=ap; fs.writeFileSync('/tmp/oag-typescript-config.json', JSON.stringify(merged,null,2));"
openapi-generator-cli generate -c /tmp/oag-typescript-config.json
```

## Docker Shortcut

From repo root:

```bash
docker build -f Dockerfile.typescript -t kiss-openapi-typescript .
docker save kiss-openapi-typescript -o kiss-openapi-typescript.tar
source .venv/bin/activate
docker-tartare extract kiss-openapi-typescript.tar /out out --dir
```

Generated client is embedded in the image at `/out/typescript-client` and extracted to `out/typescript-client`.
