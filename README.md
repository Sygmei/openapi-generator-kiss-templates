# openapi-generator-kiss-templates
Simple and stupid OpenAPI generator templates

## Templates
- `python/`: minimal Python client templates (`pydantic` models + `httpx` client + `pyproject.toml`)
- `typescript/`: minimal TypeScript client setup (`typescript-fetch`)
- `go/`: minimal Go client setup (`go` generator)

## Build Artifact With Docker
A single [`Dockerfile`](/Users/sygmei/Projects/openapi-generator-kiss-templates/Dockerfile) now contains one stage per language:
- `python`
- `typescript`
- `go`
- `all` (default final stage)

Build all languages at once:
```bash
docker build -t kiss-openapi-artifact .
docker save kiss-openapi-artifact -o kiss-openapi-artifact.tar
source .venv/bin/activate
docker-tartare extract kiss-openapi-artifact.tar /out out --dir
```

Build only one language:
```bash
docker build --target python -t kiss-openapi-python .
docker build --target typescript -t kiss-openapi-typescript .
docker build --target go -t kiss-openapi-go .
```

Each stage generates at build time and embeds output in `/out/<language>-client`.
No `docker run` step is required.

Generator options are read from:
- [`openapi-generator.config.json`](/Users/sygmei/Projects/openapi-generator-kiss-templates/openapi-generator.config.json)
  - `common`: shared options
  - `languages.python`: Python-specific options
  - `languages.typescript`: TypeScript-specific options
  - `languages.go`: Go-specific options
