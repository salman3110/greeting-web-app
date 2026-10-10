"""Runtime configuration for Gunicorn.
"""

import os

bind = f"0.0.0.0:{os.getenv('PORT', '8080')}"
workers = int(os.getenv("WEB_CONCURRENCY", "2"))
timeout = int(os.getenv("GUNICORN_TIMEOUT", "30"))
graceful_timeout = int(os.getenv("GUNICORN_GRACEFUL_TIMEOUT", "30"))

loglevel = "info"
accesslog = "-"
errorlog = "-"
capture_output = True
