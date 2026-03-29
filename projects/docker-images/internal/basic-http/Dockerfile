# Static site server: mount your HTML/files at /srv/www (read-write by default in compose).
FROM python:3.12-slim-bookworm

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:0.6.14 /uv /usr/local/bin/uv

COPY pyproject.toml README.md ./
COPY app ./app

# No uv.lock required for build; run `uv lock` locally when you have uv to pin deps for reproducible builds.
RUN uv sync --no-cache

ENV PATH="/app/.venv/bin:$PATH"
ENV BASIC_HTTP_ROOT=/srv/www
ENV PORT=8080

RUN mkdir -p /srv/www

EXPOSE 8080

CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
