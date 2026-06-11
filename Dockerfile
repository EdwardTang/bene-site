FROM python:3.12-slim
WORKDIR /app
COPY site/ /app/site/
EXPOSE 8000
# Honor Koyeb's PORT env var (shell form so ${PORT} expands)
CMD sh -c "python -m http.server ${PORT:-8000} --directory /app/site --bind 0.0.0.0"
