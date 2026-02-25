rm -rf out/; mkdir out
# Python
docker build -t kiss-openapi-artifact-python -f Dockerfile.python .
docker save kiss-openapi-artifact-python -o kiss-openapi-artifact-python.tar
docker-tartare extract kiss-openapi-artifact-python.tar --dir /out ./out
# Typescript
docker build -t kiss-openapi-artifact-typescript -f Dockerfile.typescript .
docker save kiss-openapi-artifact-typescript -o kiss-openapi-artifact-typescript.tar
docker-tartare extract kiss-openapi-artifact-typescript.tar --dir /out ./out
# Go
docker build -t kiss-openapi-artifact-go -f Dockerfile.go .
docker save kiss-openapi-artifact-go -o kiss-openapi-artifact-go.tar
docker-tartare extract kiss-openapi-artifact-go.tar --dir /out ./out
# Cleanup
rm kiss-openapi-artifact-python.tar
rm kiss-openapi-artifact-typescript.tar
rm kiss-openapi-artifact-go.tar
