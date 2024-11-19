#!/bin/bash

exec > /tmp/update_env.log 2>&1
set -e

DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
APP_PORT=${APP_PORT}
ENVIRONMENT=${ENVIRONMENT}
S3_BUCKET_NAME=${S3_BUCKET_NAME}
SNS_TOPIC_ARN=${SNS_TOPIC_ARN}
TOKEN_EXPIRATION_TIME=${TOKEN_EXPIRATION_TIME}


echo "DB_HOST=${DB_HOST}"
echo "DB_USER=${DB_USER}"
echo "DB_PASSWORD=${DB_PASSWORD}"
echo "DB_DATABASE=${DB_NAME}"
echo "PORT=${APP_PORT}"
echo "ENVIRONMENT=${ENVIRONMENT}"
echo "S3_BUCKET_NAME=${S3_BUCKET_NAME}"
echo "SNS_TOPIC_ARN=${SNS_TOPIC_ARN}"
echo "TOKEN_EXPIRATION_TIME=${TOKEN_EXPIRATION_TIME}"


sudo -u csye6225 bash -c "sed -i '/^DB_HOST=/d' /home/csye6225/webapp/.env && echo \"DB_HOST=${DB_HOST}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_USER=/d' /home/csye6225/webapp/.env && echo \"DB_USER=${DB_USER}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_PASSWORD=/d' /home/csye6225/webapp/.env && echo \"DB_PASSWORD=${DB_PASSWORD}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_DATABASE=/d' /home/csye6225/webapp/.env && echo \"DB_DATABASE=${DB_NAME}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_PORT=/d' /home/csye6225/webapp/.env && echo \"DB_PORT=5432\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^PORT=/d' /home/csye6225/webapp/.env && echo \"PORT=${APP_PORT}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^ENVIRONMENT=/d' /home/csye6225/webapp/.env && echo \"ENVIRONMENT=${ENVIRONMENT}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^S3_BUCKET_NAME=/d' /home/csye6225/webapp/.env && echo \"S3_BUCKET_NAME=${S3_BUCKET_NAME}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^SNS_TOPIC_ARN=/d' /home/csye6225/webapp/.env && echo \"SNS_TOPIC_ARN=${SNS_TOPIC_ARN}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^TOKEN_EXPIRATION_TIME=/d' /home/csye6225/webapp/.env && echo \"TOKEN_EXPIRATION_TIME=${TOKEN_EXPIRATION_TIME}\" >> /home/csye6225/webapp/.env"

# Ensure the .env file has the correct owner and permissions after writing
sudo chown csye6225:csye6225 /home/csye6225/webapp/.env
sudo chmod 600 /home/csye6225/webapp/.env

sudo systemctl daemon-reload
# sudo systemctl restart webapp_service


cat <<EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "metrics": {
    "namespace": "webappDev",
    "metrics_collected": {
      "statsd": {
        "service_address": ":8125",
        "metrics_collection_interval": 1,
        "metrics_aggregation_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "/aws/ec2/webappGroup",
            "log_stream_name": "webapp/syslog",
            "retention_in_days": 1
          }
        ]
      }
    }
  }
}
EOF

sudo chown cwagent:cwagent /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
sudo chmod 644 /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

sudo chmod 644 /var/log/syslog
sudo systemctl daemon-reload
sudo systemctl restart webapp_service
sudo systemctl restart amazon-cloudwatch-agent