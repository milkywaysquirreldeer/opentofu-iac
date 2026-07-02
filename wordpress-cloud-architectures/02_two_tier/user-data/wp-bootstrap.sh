#!/usr/bin/env bash

DBUser=$(aws ssm get-parameter --name "/A4L/Wordpress/DBUser" \
--query "Parameter.Value" --output text)
DBName=$(aws ssm get-parameter --name "/A4L/Wordpress/DBName" \
--query "Parameter.Value" --output text)
DBPassword=$(aws ssm get-parameter --name "/A4L/Wordpress/DBPassword" \
--query "Parameter.Value" --with-decryption --output text)
DBEndpoint=$(aws ssm get-parameter --name "/A4L/Wordpress/DBEndpoint" \
--query "Parameter.Value" --output text)
RDSCertificateBundle=$(aws ssm get-parameter \
--name "/A4L/Wordpress/RDSCertificateBundle" \
--query "Parameter.Value" --output text)

dnf -y update
dnf -y install httpd php8.5 php8.5-mysqlnd mariadb118-server

wget http://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
cp -rvf wordpress/* /var/www/html && rm -f latest.tar.gz; rm ./wordpress -rf
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
chown -R ec2-user:apache /var/www

usermod -a -G apache ec2-user

cd /var/www/html || exit 1
cp wp-config-sample.php wp-config.php
sed -i "s/'database_name_here'/'${DBName}'/g" wp-config.php
sed -i "s/'username_here'/'${DBUser}'/g" wp-config.php
sed -i "s/'password_here'/'${DBPassword}'/g" wp-config.php
sed -i "s/'localhost'/'${DBEndpoint}'/g" wp-config.php
rm -f /tmp/db.setup

# Add RDS CA as trusted
wget ${RDSCertificateBundle} \
-O /etc/pki/ca-trust/source/anchors/global-bundle.pem
update-ca-trust extract

systemctl enable --now httpd
