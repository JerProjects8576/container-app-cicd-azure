"""A deliberately small web service.

The application is not the point of this repository - the delivery pipeline
around it is. It only needs enough behaviour to be tested, containerised,
health-checked and observed.
"""

import os
import socket
from datetime import UTC, datetime

from fastapi import FastAPI
from fastapi.responses import HTMLResponse

# Injected at build time by the pipeline, so every running container can tell
# you exactly which commit it was built from.
GIT_SHA = os.getenv("GIT_SHA", "dev")
ENVIRONMENT = os.getenv("ENVIRONMENT", "local")

app = FastAPI(title="Container delivery demo", version=GIT_SHA)


@app.get("/healthz")
def healthz() -> dict[str, str]:
    """Liveness/readiness endpoint used by Docker, Azure and the smoke test."""
    return {"status": "ok"}


@app.get("/api/info")
def info() -> dict[str, str]:
    """Shows which build is running and which replica answered."""
    return {
        "commit": GIT_SHA,
        "environment": ENVIRONMENT,
        "replica": socket.gethostname(),
        "time_utc": datetime.now(UTC).isoformat(timespec="seconds"),
    }


@app.get("/", response_class=HTMLResponse)
def home() -> str:
    return f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Container delivery demo</title>
    <style>
      body {{ font-family: system-ui, sans-serif; max-width: 40rem; margin: 4rem auto; padding: 0 1rem; }}
      code {{ background: #eee; padding: .1rem .3rem; border-radius: .2rem; }}
    </style>
  </head>
  <body>
    <h1>It works</h1>
    <p>This container was built and deployed automatically by GitHub Actions.</p>
    <p>Commit: <code>{GIT_SHA}</code><br>Environment: <code>{ENVIRONMENT}</code></p>
    <p>See <a href="/api/info">/api/info</a> and <a href="/healthz">/healthz</a>.</p>
  </body>
</html>"""
