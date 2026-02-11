FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Azure Container Apps: expose the port you set in Ingress (use 8080)
EXPOSE 8080

CMD ["streamlit", "run", "app.py", "--server.address=0.0.0.0", "--server.port=8080", "--server.headless=true"]
