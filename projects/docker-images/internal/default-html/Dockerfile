# default-html — FastAPI static server for default landing + starfield error page.
#
# Mirrors the `internal/basic-http` pattern (uv-based build, /srv/www static root),
# but adds HTML-aware 404/500 fallback to `error.html`.
FROM python:3.12-slim-bookworm

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:0.6.14 /uv /usr/local/bin/uv

COPY pyproject.toml README.md ./
COPY app ./app

RUN uv sync --no-cache

ENV PATH="/app/.venv/bin:$PATH"
ENV BASIC_HTTP_ROOT=/srv/www
ENV PORT=8080

# Static site files (you can still override via volume mount in compose)
COPY default-site/ /srv/www/

EXPOSE 8080

CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --no-server-header"]

