FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY data/data.csv ./data/data.csv
COPY scripts/spark_job.py ./scripts/spark_job.py

CMD ["python", "scripts/spark_job.py"]