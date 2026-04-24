FROM python:3.12-slim

WORKDIR /app

# Only dependency
RUN pip install --no-cache-dir jinja2

# Copy application
COPY src/ src/
COPY scripts/ scripts/

# Make scripts executable
RUN chmod +x scripts/session-browser.sh

# Runtime config
ENV SERVER_HOST=0.0.0.0
ENV SERVER_PORT=8899

# Data directories will be mounted at runtime
ENV CLAUDE_DATA_DIR=/data/claude
ENV CODEX_DATA_DIR=/data/codex
ENV INDEX_DIR=/data/index

EXPOSE 8899

# Default: start web server (requires data volumes mounted)
CMD ["./scripts/session-browser.sh", "serve"]
