.PHONY: format lint start

format:
	uv run black .
	uv run ruff check . --fix

lint:
	uv run ruff check .

start:
	docker compose up --build
