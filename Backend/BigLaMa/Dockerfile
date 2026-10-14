# syntax=docker/dockerfile:1
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 LAMA_THREADS=2
WORKDIR /app
COPY Backend/BigLaMa/requirements.txt .
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then PIP_CERT=/run/secrets/proxy_ca pip install --no-cache-dir -r requirements.txt; else pip install --no-cache-dir -r requirements.txt; fi
COPY Backend/BigLaMa/ .
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then SSL_CERT_FILE=/run/secrets/proxy_ca python fetch_model.py; else python fetch_model.py; fi \
    && chmod -R a+rX /app /models && useradd --uid 10001 --create-home cookies
USER cookies
EXPOSE 8080
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8080} --workers 1 --no-access-log"]
