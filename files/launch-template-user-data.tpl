#! /bin/bash
while ! ip route | grep -oP 'default via .+ dev eth0'; do
  echo "interface not up, will try again in 1 second";
  sleep 1;
done
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
sudo apt-get install -y wordpress
echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html