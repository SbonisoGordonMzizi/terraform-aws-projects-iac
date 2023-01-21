#!/bin/bash
#Deploy hello world web application
yum update -y
yum -y remove httpd
yum -y remove httpd-tools
yum install -y httpd
sudo touch /var/www/html/index.html
sudo chmod 777 /var/www/html/index.html
echo "<h1>Hello World Web Application</h1>" > /var/www/html/index.html
systemctl enable httpd
systemctl start httpd