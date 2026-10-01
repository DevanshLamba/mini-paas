# syntax=docker/dockerfile:1

# Pin the exact base image so builds are reproducible; Debian "trixie" slim keeps the
# image small but, unlike Alpine, uses glibc, so Python wheels install without compiling.
ARG PYTHON_IMAGE=python:3.13.15-slim-trixie

# ---- Stage 1: install dependencies into an isolated virtualenv ----------------------
FROM ${PYTHON_IMAGE} AS builder
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH
# Copy only the requirements first, so this layer stays cached until dependencies change.
COPY requirements.txt .
RUN pip install -r requirements.txt \
 # The app never installs packages at runtime; drop the venv's pip (and the libraries it vendors).
 && pip uninstall -y pip

# ---- Stage 2: minimal runtime image (no pip, no build leftovers) --------------------
FROM ${PYTHON_IMAGE} AS runtime
LABEL org.opencontainers.image.source="https://github.com/devanshlamba/mini-paas" \
      org.opencontainers.image.description="Mini-PaaS sample FastAPI workload" \
      org.opencontainers.image.licenses="MIT"

ENV PATH=/opt/venv/bin:$PATH \
    PYTHONPATH=/app/src \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# - Apply Debian security updates published after the base image was built (Trivy gate).
# - Remove the system pip: no package installer is left for an attacker to use.
# - A fixed numeric UID lets Kubernetes verify `runAsNonRoot` without reading /etc/passwd.
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/* \
 && python -m pip uninstall -y pip \
 && groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
# Code stays root-owned and read-only to the app user, so a compromised process can't modify it.
COPY src/ ./src/

# Declared late: the version changes on every commit and would otherwise invalidate the
# (slow) layers above it.
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

USER 10001:10001
EXPOSE 8000

# Used by docker/compose only; Kubernetes uses its own probes (Phase 2).
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

# Exec-form CMD makes uvicorn PID 1, so it receives SIGTERM directly and shuts down gracefully.
CMD ["uvicorn", "sampleapi.main:app", "--host", "0.0.0.0", "--port", "8000", \
     "--no-access-log", "--timeout-graceful-shutdown", "20"]
