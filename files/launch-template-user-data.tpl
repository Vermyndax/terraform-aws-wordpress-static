#! /bin/bash
while ! ip route | grep -oP 'default via .+ dev eth0'; do
  echo "interface not up, will try again in 1 second";
  sleep 1;
done
sudo apt-get update
sudo apt-get install -y php php-dom php-gd php-mysql php-curl nfs-common mysql-client
### Mount EFS Share
echo "${efs_dns_name}:/ /var/www/html nfs defaults,vers=4.1 0 0" >> /etc/fstab
for z in {0..120}; do
    echo -n .
    host "${efs_dns_name}" && break
    sleep 1
done
mount -a
### End Mount EFS Share
### Install Wordpress and Apache2
sudo apt-get install -y apache2
cd /tmp
wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
cd /var/www/html
sudo wp core download --allow-root
# echo "<h1>Healthcheck File</h1>" > /var/www/html/index.html
echo "# BEGIN WordPress" > /var/www/html/.htaccess
echo "<IfModule mod_rewrite.c>" >> /var/www/html/.htaccess
# echo "DirectoryIndex index.php index.html /index.php" >> /var/www/html/.htaccess
echo "RewriteEngine On" >> /var/www/html/.htaccess
echo "RewriteBase /" >> /var/www/html/.htaccess
echo "RewriteCond %%{HTTPS} off" >> /var/www/html/.htaccess
echo "RewriteRule ^ https://%%{HTTP_HOST}%%{REQUEST_URI} [L,R=301]" >> /var/www/html/.htaccess
echo "RewriteRule ^index\.php$ - [L]" >> /var/www/html/.htaccess
echo "RewriteCond %%{REQUEST_FILENAME} !-f" >> /var/www/html/.htaccess
echo "RewriteCond %%{REQUEST_FILENAME} !-d" >> /var/www/html/.htaccess
echo "RewriteRule . /index.php [L]" >> /var/www/html/.htaccess
echo "</IfModule>" >> /var/www/html/.htaccess
echo "# END WordPress" >> /var/www/html/.htaccess
sudo wp core config --allow-root --dbname='${database_name}' --dbuser='${database_username}' --dbpass='${database_password}' --dbhost='${database_instance}' --dbprefix='${database_prefix}'
sudo wp core install --allow-root --url='https://${site_hostname}' --title='${blog_title}' --admin_user='${admin_user}' --admin_password='${admin_password}' --admin_email='${admin_email}'
sed '/^anothervalue=.*/a after=me' test.txt
TEXT="if (strpos($$_SERVER[\'HTTP_X_FORWARDED_PROTO\'], \'https\') !== false)\n\   $$_SERVER[\'HTTPS\']=\'on\';"
sed "/^\$$table_prefix =.*/a $$TEXT" /var/www/html/wp-config.php
sed -i 's/ServerAdmin root@localhost/ServerAdmin admin@${site_edit_name}/' /etc/apache2/sites-available/000-default.conf
chown -R www-data:www-data /var/www/html
systemctl enable apache2
systemctl start apache2
