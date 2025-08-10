IMAGE_NAME := weather-fastapi-gcp
PORT := 8080

.PHONY: docker-build docker-run format lint start

.PHONY: docker-build
docker-build:
	docker build -t $(IMAGE_NAME) .

.PHONY: docker-run
docker-run:
	docker run --rm -p $(PORT):8080 -e PORT=8080 $(IMAGE_NAME)

.PHONY: curl
curl:
	curl -s "http://127.0.0.1:$(PORT)/weather?lat=51.5074&lon=-0.1278&units=metric&city=London" | jq .

format:
	uv run black .
	uv run ruff check . --fix

lint:
	uv run ruff check .

start:
	docker compose up --build
