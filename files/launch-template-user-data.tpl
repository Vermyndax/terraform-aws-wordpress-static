#! /bin/bash
while ! ip route | grep -oP 'default via .+ dev eth0'; do
  echo "interface not up, will try again in 1 second";
  sleep 1;
done
sudo apt-get update
yum install -y php php-dom php-gd php-mysql nfs-utils
echo "${efs_dns_name}:/ /var/www/html nfs defaults,vers=4.1 0 0" >> /etc/fstab
for z in {0..120}; do
    echo -n .
    host "${aefs_dns_name}" && break
    sleep 1
done
sudo apt-get install -y apache2
cd /tmp
wget https://www.wordpress.org/latest.tar.gz
mount -a
tar xzvf /tmp/latest.tar.gz --strip 1 -C /var/www/html
rm /tmp/latest.tar.gz
chown -R apache:apache /var/www/html
sed -i 's/#ServerName www.example.com:80/ServerName www.myblog.com:80/' /etc/apache2/conf/httpd.conf
sed -i 's/ServerAdmin root@localhost/ServerAdmin admin@myblog.com/' /etc/apache2/conf/httpd.conf
#setsebool -P httpd_can_network_connect 1
#setsebool -P httpd_can_network_connect_db 1
systemctl enable apache2
systemctl start apache2
#firewall-cmd --zone=public --permanent --add-service=http
#firewall-cmd --reload
#iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
#iptables -A OUTPUT -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED -j ACCEPT
