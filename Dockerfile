# ---- Stage 1: install dependencies -----------------------------------------
# Build tools and pip caches stay in this stage and never reach the final image.
FROM python:3.13-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 2: the image that actually runs ---------------------------------
FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Run as an unprivileged user: if the app is compromised, the attacker is not root.
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser

WORKDIR /srv
COPY --from=builder /install /usr/local
COPY app/ ./app/

# The pipeline passes the commit hash, so each image knows where it came from.
ARG GIT_SHA=dev
ENV GIT_SHA=${GIT_SHA}

USER 10001
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2)"]

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
