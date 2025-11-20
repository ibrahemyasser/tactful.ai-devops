FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y apache2-utils && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /seed

COPY . .

RUN chmod +x generate-votes.sh

RUN python make-data.py

CMD ["./generate-votes.sh"]