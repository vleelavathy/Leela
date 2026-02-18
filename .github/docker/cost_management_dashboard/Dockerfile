FROM mcr.microsoft.com/azure-cli:2.65.0

WORKDIR /app

# Azure CLI image already has python/pip (but we still do a safe install)
RUN python -m pip install --upgrade pip

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080
CMD ["streamlit", "run", "app.py", "--server.address=0.0.0.0", "--server.port=8080", "--server.headless=true"]
