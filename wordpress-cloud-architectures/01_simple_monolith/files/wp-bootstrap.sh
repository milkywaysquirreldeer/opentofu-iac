#!/usr/bin/env bash

DBUser=$(aws ssm get-parameter --name "/A4L/Wordpress/DBUser" \
--query "Parameter.Value" --output text)
DBName=$(aws ssm get-parameter --name "/A4L/Wordpress/DBName" \
--query "Parameter.Value" --output text)
DBPassword=$(aws ssm get-parameter --name "/A4L/Wordpress/DBPassword" \
--query "Parameter.Value" --with-decryption --output text)
DBRootPassword=$(aws ssm get-parameter --name "/A4L/Wordpress/DBRootPassword" \
--query "Parameter.Value" --with-decryption --output text)

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

systemctl enable --now mariadb

cd /var/www/html || exit 1
cp wp-config-sample.php wp-config.php
sed -i "s/'database_name_here'/'${DBName}'/g" wp-config.php
sed -i "s/'username_here'/'${DBUser}'/g" wp-config.php
sed -i "s/'password_here'/'${DBPassword}'/g" wp-config.php
echo "CREATE DATABASE ${DBName};" >> /tmp/db.setup
echo "CREATE USER '${DBUser}'@'localhost' IDENTIFIED BY '${DBPassword}';" >> /tmp/db.setup
echo "GRANT ALL ON ${DBName}.* TO '${DBUser}'@'localhost';" >> /tmp/db.setup
echo "FLUSH PRIVILEGES;" >> /tmp/db.setup

mariadb -u root --password=${DBRootPassword} < /tmp/db.setup
rm -f /tmp/db.setup

systemctl enable --now httpd
