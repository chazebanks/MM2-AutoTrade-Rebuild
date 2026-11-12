# Railway backend worker only. Build context must be repository root.
# Image contains no P3/P4 controller, browser client or API credentials.
FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app

# Namespace package; only the backend library ships to the private worker.
COPY pdiddler/backend/ /app/pdiddler/backend/

# SQLite /data must be overlaid with a real Railway persistent volume.
RUN mkdir -p /data \
    && python -m py_compile /app/pdiddler/backend/runtime.py /app/pdiddler/backend/persistent_store.py

# No exposed TCP port, no HTTP provider, no Discord, no user-provided secrets.
# This service is never a replacement for the live MM2 client.
CMD ["python", "-m", "pdiddler.backend.runtime", "worker", "--db", "/data/gingerscope.sqlite"]
