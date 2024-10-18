#!/bin/bash

# Enable logging to a file for troubleshooting
exec > /tmp/update_env.log 2>&1
set -e

# Database variables
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}

# Log the variables for debugging
echo "DB_HOST=${DB_HOST}"
echo "DB_USER=${DB_USER}"
echo "DB_PASSWORD=${DB_PASSWORD}"
echo "DB_NAME=${DB_NAME}"

echo "Waiting for RDS instance to be ready..."

# Retry until RDS is accessible
while ! nc -z ${DB_HOST} 5432; do
  echo "Waiting for RDS to be accessible..."
  sleep 10
done

echo "RDS is now accessible."

# Ensure the .env file has the correct owner and permissions before writing
sudo chown csye6225:csye6225 /home/csye6225/webapp/.env
sudo chmod 600 /home/csye6225/webapp/.env

# Update or append environment variables using escaped quotes for variable expansion
sudo -u csye6225 bash -c "sed -i '/^DB_HOST=/d' /home/csye6225/webapp/.env && echo \"DB_HOST=${DB_HOST}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_USER=/d' /home/csye6225/webapp/.env && echo \"DB_USER=${DB_USER}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_PASSWORD=/d' /home/csye6225/webapp/.env && echo \"DB_PASSWORD=${DB_PASSWORD}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_DATABASE=/d' /home/csye6225/webapp/.env && echo \"DB_DATABASE=${DB_NAME}\" >> /home/csye6225/webapp/.env"
sudo -u csye6225 bash -c "sed -i '/^DB_PORT=/d' /home/csye6225/webapp/.env && echo \"DB_PORT=5432\" >> /home/csye6225/webapp/.env"

# Ensure the .env file has the correct owner and permissions after writing
sudo chown csye6225:csye6225 /home/csye6225/webapp/.env
sudo chmod 600 /home/csye6225/webapp/.env

# Start the application service
sudo systemctl start webapp_service || { echo "Failed to start service"; exit 1; }
echo "Web application started."