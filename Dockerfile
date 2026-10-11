ARG PYTHON_VERSION=3.12

# Build image and dependencies
FROM python:${PYTHON_VERSION}-slim@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1 AS builder
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1
# Python virtual environment is created in /opt/venv to isolate the application dependencies from the system Python packages. The PATH environment variable is updated to include the virtual environment's bin directory, ensuring that the installed packages are used when running the application.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

WORKDIR /build
COPY app/requirements.txt ./requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Minimal runtime production image
FROM python:${PYTHON_VERSION}-slim@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1 AS production

LABEL org.opencontainers.image.title="greeting-web-app" \
      org.opencontainers.image.description="Minimal Flask greeting application served by Gunicorn" \
      org.opencontainers.image.source="https://github.com/salman3110/greeting-web-app"

ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY --chown=app:app gunicorn.conf.py ./gunicorn.conf.py
COPY --chown=app:app app/ ./app/

USER 10001:10001

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/healthz' % os.environ.get('PORT', '8080'), timeout=2)"]

CMD ["gunicorn", "--config", "/app/gunicorn.conf.py", "--chdir", "/app/app", "app:app"]
