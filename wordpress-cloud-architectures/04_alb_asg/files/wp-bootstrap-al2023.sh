#!/usr/bin/env bash

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
RDSCertificateBundle=$(aws ssm get-parameter \
--name "/A4L/Wordpress/RDSCertificateBundle" \
--query "Parameter.Value" --output text)

dnf -y update
dnf -y install httpd php8.5 php8.5-mysqlnd mariadb118-server amazon-efs-utils

mkdir -p /var/www/html/wp-content
chown -R ec2-user:apache /var/www/

echo -e "$EFSFSID:/ /var/www/html/wp-content efs _netdev,tls,iam 0 0" >> /etc/fstab
mount -a -t efs defaults

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

# Workaround for WordPress hard-coded URLs (in case of any IP address changes throughout life of project)
cat >> /home/ec2-user/update_wp_ip.sh<< 'EOF'
#!/usr/bin/env bash

source <(php -r 'require("/var/www/html/wp-config.php"); echo("DB_NAME=".DB_NAME."; DB_USER=".DB_USER."; DB_PASSWORD=".DB_PASSWORD."; DB_HOST=".DB_HOST); ')
SQL_COMMAND="mariadb -u $DB_USER -h $DB_HOST -p$DB_PASSWORD $DB_NAME -e"
OLD_URL=$(mariadb -u $DB_USER -h $DB_HOST -p$DB_PASSWORD $DB_NAME -e 'select option_value from wp_options where option_name = "siteurl";' | grep http)

NEW_URL=$(curl -H "X-aws-ec2-metadata-token: $(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")" http://169.254.169.254/latest/meta-data/public-ipv4)

$SQL_COMMAND "UPDATE wp_options SET option_value = replace(option_value, '$OLD_URL', 'http://$NEW_URL') WHERE option_name = 'home' OR option_name = 'siteurl';"
$SQL_COMMAND "UPDATE wp_posts SET guid = replace(guid, '$OLD_URL','http://$NEW_URL');"
$SQL_COMMAND "UPDATE wp_posts SET post_content = replace(post_content, '$OLD_URL', 'http://$NEW_URL');"
$SQL_COMMAND "UPDATE wp_postmeta SET meta_value = replace(meta_value,'$OLD_URL','http://$NEW_URL');"
EOF

chmod 755 /home/ec2-user/update_wp_ip.sh
echo "/home/ec2-user/update_wp_ip.sh" >> /etc/rc.local
/home/ec2-user/update_wp_ip.sh

systemctl enable --now httpd
