# DevOps Interview Task (Part 1): Containerize

**This is a take-home task.** Please submit by the date given when the task was
issued.

## Overview

You are given a small web application (`app/`). A working `Dockerfile` is
provided, but it was written quickly and does **not** follow container best
practices. Your job is to refactor it into a production-quality image and push
it to a container registry.

You do **not** need to modify the application code.

## What we provide

Clone this repository into your local account.

> **Do Not** fork this repository. Clone it and re-push it into your local account.

The following is provided as part of this repository:

```text
Dockerfile            # a working but non-production Dockerfile — improve it
app/
  app.py              # a minimal Python Flask web app (do not modify)
  requirements.txt    # the app's dependencies (do not modify)
```

The application:

-   Listens on the port given by the `PORT` environment variable (default `8080`).
-   Reads a `GREETING` environment variable used in its response.
-   Exposes `GET /`, `GET /healthz`, and `GET /info`.

## Container image

### Build and run

```bash
docker build -t greeting-web-app .
docker run --rm -p 8080:8080 -e GREETING="Hello" greeting-web-app

curl localhost:8080/          # greeting
curl localhost:8080/healthz   # liveness / readiness
curl localhost:8080/info      # runtime info
```

To run it the way it would run in production (read-only filesystem, no Linux
capabilities, no privilege escalation):

```bash
docker run --rm -p 8080:8080 \
  --read-only --tmpfs /tmp \
  --cap-drop=ALL --security-opt=no-new-privileges:true \
  greeting-web-app
```

### What the Dockerfile does

-   **Reproducible base:** `python:3.12-slim` pinned by digest, so builds always
    start from the same image.
-   **Multi-stage build:** dependencies are installed into a virtualenv in a
    builder stage; only that virtualenv is copied into the final image, so pip,
    caches and build tooling are not shipped.
-   **Small image:** slim base, no compilers, curl or editors.
-   **Fast rebuilds:** `requirements.txt` is installed before the app code is
    copied, so code changes do not reinstall dependencies. A BuildKit cache
    mount keeps pip's download cache between builds.
-   **Non-root:** runs as an unprivileged user (UID/GID `10001`).
-   **Clean shutdown:** gunicorn is started in exec form, so it is PID 1 and
    receives `SIGTERM` directly.
-   **Observability:** logs go to stdout/stderr; a `HEALTHCHECK` calls
    `/healthz` using the Python already in the image (no curl needed).
-   **Small build context:** `.dockerignore` keeps git history, docs and local
    env files out of the build.

The application code in `app/` is unchanged.

### Configuration

All settings are environment variables, read by `gunicorn.conf.py`:

| Variable                    | Default                      | Purpose                         |
| --------------------------- | ---------------------------- | ------------------------------- |
| `GREETING`                  | `Hello from the sample app!` | Message returned by `GET /`     |
| `PORT`                      | `8080`                       | Port gunicorn listens on        |
| `WEB_CONCURRENCY`           | `2`                          | Number of gunicorn workers      |
| `GUNICORN_TIMEOUT`          | `30`                         | Worker timeout (seconds)        |
| `GUNICORN_GRACEFUL_TIMEOUT` | `30`                         | Graceful shutdown time (seconds)|

On Kubernetes, point liveness and readiness probes at `/healthz`; the Docker
`HEALTHCHECK` is ignored there.

### CI

`.github/workflows/container-security.yml` runs on every pull request and push
to `main`:

1.  Lints the Dockerfile with hadolint.
2.  Builds the image.
3.  Runs `scripts/container-smoke-test.sh`, which starts the container with a
    read-only filesystem and dropped capabilities, checks `/healthz`, `/` and
    `/info`, and verifies the process is not running as root.
4.  Scans the image with Trivy and fails on fixable HIGH or CRITICAL
    vulnerabilities.

Dependabot (`.github/dependabot.yml`) keeps the base image, Python
dependencies and GitHub Actions up to date.
