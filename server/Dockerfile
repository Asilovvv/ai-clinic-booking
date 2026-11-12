# Image of the Smile AI server for any container hosting.
FROM python:3.12-slim

WORKDIR /srv
COPY requirements.txt requirements-prod.txt ./
RUN pip install --no-cache-dir -r requirements.txt -r requirements-prod.txt
COPY app ./app

ENV PYTHONUNBUFFERED=1
EXPOSE 8000
# Hosting providers pass the port in $PORT.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
