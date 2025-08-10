FROM python:3.13-alpine

RUN apk add --no-cache curl ca-certificates tini

RUN pip install uv==0.8.8

WORKDIR /app

COPY pyproject.toml uv.lock README.md ./

RUN uv sync --frozen --no-install-project

COPY src/ ./src/

RUN uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:${PATH}"

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["uvicorn", "weather_fastapi_gcp.main:app", "--host", "0.0.0.0", "--port", "8080"]
