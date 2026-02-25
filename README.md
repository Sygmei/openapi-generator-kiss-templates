# openapi-generator-kiss-templates
Simple and stupid OpenAPI generator templates

## Templates
- `python/`: minimal Python client templates (`pydantic` models + `httpx` client + `pyproject.toml`)
- `typescript/`: minimal TypeScript client setup (`typescript-fetch`)
- `go/`: minimal Go client setup (`go` generator)

## Build Artifact With Docker
Build Python:
```bash
docker build -f Dockerfile.python -t kiss-openapi-python .
```

Save image layers:
```bash
docker save kiss-openapi-python -o kiss-openapi-python.tar
```

Extract `/out` with `docker-tartare` (installed in local `.venv`):
```bash
source .venv/bin/activate
docker-tartare extract kiss-openapi-python.tar /out out --dir
```

Build TypeScript:
```bash
docker build -f Dockerfile.typescript -t kiss-openapi-typescript .
docker save kiss-openapi-typescript -o kiss-openapi-typescript.tar
source .venv/bin/activate
docker-tartare extract kiss-openapi-typescript.tar /out out --dir
```

Build Go:
```bash
docker build -f Dockerfile.go -t kiss-openapi-go .
docker save kiss-openapi-go -o kiss-openapi-go.tar
source .venv/bin/activate
docker-tartare extract kiss-openapi-go.tar /out out --dir
```

This image is generated at build time; no `docker run` step is required.
Generator options are read from:
- [`openapi-generator.config.json`](/Users/sygmei/Projects/openapi-generator-kiss-templates/openapi-generator.config.json)
  - `common`: shared options
  - `languages.python`: Python-specific options
  - `languages.typescript`: TypeScript-specific options
  - `languages.go`: Go-specific options
