#!/usr/bin/env bash

# The AMI selected for this launch template should already have the following loaded:
# - httpd php8.5 php8.5-mysqlnd mariadb118-server amazon-efs-utils
# - RDS certificate bundle added to ca-trust (for SSL connectivity to DB)
# - Wordpress installed and install source still present in /home/ec2/wordpress

DBUser=$(aws ssm get-parameter --name "/A4L/Wordpress/DBUser" \
--query "Parameter.Value" --output text)
DBName=$(aws ssm get-parameter --name "/A4L/Wordpress/DBName" \
--query "Parameter.Value" --output text)
DBPassword=$(aws ssm get-parameter --name "/A4L/Wordpress/DBPassword" \
--query "Parameter.Value" --with-decryption --output text)
DBEndpoint=$(aws ssm get-parameter --name "/A4L/Wordpress/DBEndpoint" \
--query "Parameter.Value" --output text)
EFSFSID=$(aws ssm get-parameter --name "/A4L/Wordpress/EFSFSID" \
--query "Parameter.Value" --output text)

wp_content_dir=/var/www/html/wp-content

# Mount EFS volume
echo -e "$EFSFSID:/ /var/www/html/wp-content efs _netdev,tls,iam 0 0" >> /etc/fstab
mount -a -t efs defaults

# Restore default wp-content to new EFS mount if not already present
if [ ! -d "${wp_content_dir}/themes" || ! -d "${wp_content_dir}/plugins" ]
then
  cd /home/ec2-user
  cp -rvf wordpress/wp-content/* ${wp_content_dir}
fi
# Clean up install source
rm -f latest.tar.gz; rm ./wordpress -rf

# Fix user and file permissions
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
chown -R ec2-user:apache /var/www

usermod -a -G apache ec2-user

# Configure DB connection details in WP
cd /var/www/html || exit 1
sed -i "s/'database_name_here'/'${DBName}'/g" wp-config.php
sed -i "s/'username_here'/'${DBUser}'/g" wp-config.php
sed -i "s/'password_here'/'${DBPassword}'/g" wp-config.php
sed -i "s/'localhost'/'${DBEndpoint}'/g" wp-config.php

systemctl enable --now httpd
