rm -rf out/; mkdir out
docker build -t kiss-openapi-artifact .
docker save kiss-openapi-artifact -o kiss-openapi-artifact.tar
docker-tartare extract kiss-openapi-artifact.tar --dir /out ./out
rm kiss-openapi-artifact.tar