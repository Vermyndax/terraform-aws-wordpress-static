#! /bin/bash
while ! ip route | grep -oP 'default via .+ dev eth0'; do
  echo "interface not up, will try again in 1 second";
  sleep 1;
done
sudo apt-get update
sudo apt-get install -y php php-dom php-gd php-mysql nfs-common
echo "${efs_dns_name}:/ /var/www/html nfs defaults,vers=4.1 0 0" >> /etc/fstab
for z in {0..120}; do
    echo -n .
    host "${efs_dns_name}" && break
    sleep 1
done
sudo apt-get install -y apache2
cd /tmp
wget https://www.wordpress.org/latest.tar.gz
mount -a
tar xzvf /tmp/latest.tar.gz --strip 1 -C /var/www/html
rm /tmp/latest.tar.gz
echo "<h1>Healthcheck File</h1>" > /var/www/html/index.html
echo "# BEGIN WordPress" > /var/www/html/.htaccess
echo "DirectoryIndex index.php index.html /index.php" >> /var/www/html/.htaccess
echo "RewriteEngine On" >> /var/www/html/.htaccess
echo "RewriteBase /" >> /var/www/html/.htaccess
echo "RewriteRule ^index\.php$ - [L]" >> /var/www/html/.htaccess
echo "RewriteCond %%{REQUEST_FILENAME} !-f" >> /var/www/html/.htaccess
echo "RewriteCond %%{REQUEST_FILENAME} !-d" >> /var/www/html/.htaccess
echo "RewriteRule . /index.php [L]" >> /var/www/html/.htaccess
echo "# END WordPress" >> /var/www/html/.htaccess
chown -R www-data:www-data /var/www/html
# sed -i 's/#ServerName www.example.com:80/ServerName ${site_edit_name}:80/' /etc/apache2/sites-available/000-default.conf
sed -i 's/ServerAdmin root@localhost/ServerAdmin admin@${site_edit_name}/' /etc/apache2/sites-available/000-default.conf
#setsebool -P httpd_can_network_connect 1
#setsebool -P httpd_can_network_connect_db 1
systemctl enable apache2
systemctl start apache2
#firewall-cmd --zone=public --permanent --add-service=http
#firewall-cmd --reload
#iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
#iptables -A OUTPUT -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED -j ACCEPT
