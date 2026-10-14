# syntax=docker/dockerfile:1
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 LAMA_THREADS=2
WORKDIR /app
COPY Backend/BigLaMa/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY Backend/BigLaMa/ .
RUN python fetch_model.py && chmod -R a+rX /app /models && useradd --uid 10001 --create-home cookies
USER cookies
EXPOSE 8080
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT:-8080} --workers 1 --no-access-log"]
