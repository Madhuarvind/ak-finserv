import multiprocessing
import os

# Gunicorn configuration

bind = os.getenv("GUNICORN_BIND", "0.0.0.0:8000")
workers = int(os.getenv("GUNICORN_WORKERS", multiprocessing.cpu_count() * 2 + 1))
threads = int(os.getenv("GUNICORN_THREADS", 2))
timeout = int(os.getenv("GUNICORN_TIMEOUT", 120))
loglevel = os.getenv("GUNICORN_LOG_LEVEL", "info")

# Logging
accesslog = "-"  # stdout
errorlog = "-"   # stderr

# Security
forwarded_allow_ips = "*"
