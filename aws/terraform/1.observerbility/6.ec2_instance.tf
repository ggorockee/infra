resource "aws_instance" "linux-server" {
  count                       = 1
  ami                         = local.ec2.ami
  instance_type               = local.ec2.type
  subnet_id                   = data.aws_subnets.private.ids[0]
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = data.aws_iam_instance_profile.CWSSM.name
  key_name                    = ""
  associate_public_ip_address = false // public일때

  root_block_device {
    volume_size = local.ec2.volume_size
    volume_type = local.ec2.volume_type
  }

  # lifecycle {
  #   ignore_changes = [associate_public_ip_address]
  # }

  user_data = <<-EOF
#!/bin/bash

cd /root

yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker

curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

mkdir -p /root/otel/{collector,prometheus,rest-app} grafana/provisioning/{dashboards,datasources}

cat << EOD > /root/docker-compose.yml
version: '3.9'

services:
  opentelemetry-collector:
    image: otel/opentelemetry-collector-contrib:latest
    volumes:
      - ./otel/collector/otel-collector-config.yaml:/etc/otel-collector-config.yaml
    ports:
      - "4317:4317"

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./otel/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    ports:
      - "3000:3000"

  node-exporter:
    image: prom/node-exporter:latest
    pid: host
    volumes:
      - '/:/host:ro,rslave'
    ports:
      - "9100:9100"

volumes:
  grafana_data:
EOD

cat << EOD > /root/otel/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:4317']
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOD

cat << EOD > /root/otel/collector/otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

exporters:
  prometheus:
    endpoint: "prometheus:9090"

service:
  pipelines:
    metrics:
      receivers: [otlp]
      exporters: [prometheus]
EOD

docker-compose up -d

EOF

  tags = merge(
    {
      Name = "OBSERVERBILITY-OTEL-PROM-GRAFANA"
    },
    {
      Environment = "dev"
      Role        = "observer"
    },
  )
}
