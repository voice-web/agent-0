"""recon-lab — site-agnostic URL scanner UI + JSON API."""

from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from app.recon import run_info_scan, run_vuln_scan, validate_target_url

_ROOT = Path(__file__).resolve().parent.parent
_SITE = _ROOT / "site"

app = FastAPI(title="recon-lab", version="0.0.3")


class ScanIn(BaseModel):
    url: str = Field(..., min_length=4, max_length=2048)


def _bad_url(detail: str) -> None:
    raise HTTPException(status_code=400, detail=detail)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "recon-lab", "version": "0.0.3"}


@app.post("/api/scan/info")
def api_scan_info(body: ScanIn) -> JSONResponse:
    _, err = validate_target_url(body.url)
    if err:
        _bad_url(err)
    report = run_info_scan(body.url)
    if not report.get("ok"):
        return JSONResponse(report, status_code=422)
    return JSONResponse(report)


@app.post("/api/scan/vuln")
def api_scan_vuln(body: ScanIn) -> JSONResponse:
    _, err = validate_target_url(body.url)
    if err:
        _bad_url(err)
    report = run_vuln_scan(body.url)
    if not report.get("ok"):
        return JSONResponse(report, status_code=422)
    return JSONResponse(report)


@app.post("/api/scan")
def api_scan_legacy(body: ScanIn) -> JSONResponse:
    """Backward-compatible alias for info scan."""
    _, err = validate_target_url(body.url)
    if err:
        _bad_url(err)
    report = run_info_scan(body.url)
    if not report.get("ok"):
        return JSONResponse(report, status_code=422)
    return JSONResponse(report)


@app.get("/")
async def index() -> FileResponse:
    idx = _SITE / "index.html"
    if not idx.is_file():
        raise HTTPException(status_code=500, detail="missing site/index.html")
    return FileResponse(idx)


if _SITE.is_dir():
    app.mount("/static", StaticFiles(directory=str(_SITE)), name="static")
