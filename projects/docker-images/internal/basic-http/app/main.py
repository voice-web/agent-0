"""Serve files from a single directory on disk (default /srv/www)."""
from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

_ROOT = Path(os.environ.get("BASIC_HTTP_ROOT", "/srv/www")).resolve()


def _ensure_root() -> Path:
    if not _ROOT.is_dir():
        raise RuntimeError(
            f"BASIC_HTTP_ROOT is not a directory: {_ROOT} "
            "(mount a host folder to /srv/www in compose, or create the path)"
        )
    return _ROOT


app = FastAPI(title="basic-http", version="0.0.1")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "root": str(_ROOT)}


_root = _ensure_root()
app.mount("/", StaticFiles(directory=str(_root), html=True), name="site")
