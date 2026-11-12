#!/usr/bin/env bash

# Prepare AMI
# This AMI provides:
# - httpd php8.5 php8.5-mysqlnd mariadb118-server amazon-efs-utils
# - RDS certificate bundle added to ca-trust (for SSL connectivity to DB)
# - Wordpress installed and install source still present in /home/ec2/wordpress
rds_certbundle_url=https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
wp_download_url=https://wordpress.org/latest.tar.gz

# Set up temporary swap for dnf on low-RAM instance
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Install dependencies
dnf -y update
dnf -y install httpd php8.5 php8.5-mysqlnd mariadb118-server amazon-efs-utils

# Remove temporary swap
swapoff /swapfile
rm -f /swapfile

# Install WordPress (keep install source)
mkdir -p /var/www/html/wp-content
chown -R ec2-user:apache /var/www/

wget ${wp_download_url}
tar -xvzf latest.tar.gz
cp -rvf wordpress/* /var/www/html

cd /var/www/html || exit 1
cp wp-config-sample.php wp-config.php

# Fix user and file permissions
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
chown -R ec2-user:apache /var/www

usermod -a -G apache ec2-user

# Add RDS CA as trusted
wget ${rds_certbundle_url} \
-O /etc/pki/ca-trust/source/anchors/global-bundle.pem
update-ca-trust extract
