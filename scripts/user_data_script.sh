#!/bin/bash

# Enable logging to a file for troubleshooting
exec > /tmp/update_env.log 2>&1
set -e

# Database variables
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
APP_PORT=${APP_PORT}

# Log the variables for debugging
echo "DB_HOST=${DB_HOST}"
echo "DB_USER=${DB_USER}"
echo "DB_PASSWORD=${DB_PASSWORD}"
echo "DB_DATABASE=${DB_NAME}"
echo "PORT=${APP_PORT}"


sudo -u csye6225 bash -c "sed -i '/^DB_HOST=/d' /home/csye6225/webapp/.env && echo \"DB_HOST=${DB_HOST}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_USER=/d' /home/csye6225/webapp/.env && echo \"DB_USER=${DB_USER}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_PASSWORD=/d' /home/csye6225/webapp/.env && echo \"DB_PASSWORD=${DB_PASSWORD}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_DATABASE=/d' /home/csye6225/webapp/.env && echo \"DB_DATABASE=${DB_NAME}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_PORT=/d' /home/csye6225/webapp/.env && echo \"DB_PORT=5432\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^PORT=/d' /home/csye6225/webapp/.env && echo \"PORT=${APP_PORT}\" >> /home/csye6225/webapp/.env"

# Ensure the .env file has the correct owner and permissions after writing
sudo chown csye6225:csye6225 /home/csye6225/webapp/.env
sudo chmod 600 /home/csye6225/webapp/.env

sudo systemctl daemon-reload
sudo systemctl restart webapp_service