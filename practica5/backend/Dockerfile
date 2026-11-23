FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PORT=5000
EXPOSE 5000

# gunicorn en lugar del servidor de desarrollo de Flask. Render inyecta $PORT.
# --preload: la app (tablas y admin) se inicializa una sola vez antes de crear los workers.
CMD ["sh", "-c", "gunicorn --preload --bind 0.0.0.0:${PORT} --workers 2 --timeout 60 --access-logfile - run:app"]
