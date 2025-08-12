# Builder Stage
FROM python:3.13-alpine AS builder
WORKDIR /app

RUN apk add --no-cache ca-certificates gcc musl-dev libffi-dev \
    && update-ca-certificates

RUN python3 -m venv /root/.local
ENV PATH=/root/.local/bin:$PATH

COPY pyproject.toml uv.lock ./
COPY src ./src

RUN pip install --upgrade pip --no-cache-dir \
    && pip install uv \
    && uv sync --frozen --no-dev
# Final Stage
FROM python:3.13-alpine
WORKDIR /app

RUN apk add --no-cache ca-certificates libffi && update-ca-certificates

RUN pip install --no-cache-dir uv==0.8.8

ENV UV_PROJECT_ENVIRONMENT=/root/.local
ENV PATH=/root/.local/bin:$PATH

COPY --from=builder /app/.venv /root/.local
COPY --from=builder /app/pyproject.toml /app/uv.lock ./

COPY src /app/src

ENV PYTHONPATH=/app/src

EXPOSE 8080

ENTRYPOINT ["python", "-m", "weather_fastapi_gcp.run"]
