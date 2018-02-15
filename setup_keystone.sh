sudo yum install -y vim git unzip wget fontconfig net-tools telnet epel-release
sudo yum install -y python-pip gcc python-devel openssl-devel

sudo pip install virtualenv
sudo ifup eth1

cd $HOME 
git clone https://github.com/openstack/keystone.git

#mkdir -p ~/venv/keystone
#virtualenv ~/venv/keystone
#source ~/venv/keystone/bin/activate

cd $HOME/keystone
echo 'pika>=0.9,<0.11' >> requirements.txt
sudo pip install -r requirements.txt
sudo pip install -e .

sudo mkdir /etc/keystone
sudo chown $USER:$USER /etc/keystone
cp -a  etc/* /etc/keystone
cp /etc/keystone.conf.sample /etc/keystone/keystone.conf
sudo sed -i "/\[database\]/aconnection=sqlite:////$HOME/keystone/keystone.db" /etc/keystone/keystone.conf

mkdir -p /etc/keystone/fernet-keys/
keystone-manage db_sync
keystone-manage fernet_setup

# setup apache
sudo yum install -y httpd mod_wsgi
sudo cp ~/keystone/httpd/wsgi-keystone.conf /etc/httpd/conf.d/
sudo sed -i "s/user=keystone/user=$USER/g" /etc/httpd/conf.d/wsgi-keystone.conf                                                     
sudo sed -i "s/group=keystone/group=$USER/g" /etc/httpd/conf.d/wsgi-keystone.conf
sudo sed -i "s|/var/log/apache2|/var/log/httpd|g" /etc/httpd/conf.d/wsgi-keystone.conf
sudo sed -i "s|/usr/local/bin/keystone-wsgi-public|$(which keystone-wsgi-public)|g" /etc/httpd/conf.d/wsgi-keystone.conf
sudo sed -i "s|/usr/local/bin/keystone-wsgi-admin|$(which keystone-wsgi-admin)|g" /etc/httpd/conf.d/wsgi-keystone.conf
sudo sed -i "s|/usr/local/bin|/usr/bin|g" /etc/httpd/conf.d/wsgi-keystone.conf
sudo chown $USER:$USER $(which keystone-wsgi-public)
sudo chown $USER:$USER $(which keystone-wsgi-admin)

sudo systemctl enable httpd.service
sudo systemctl start httpd.service

# now setup keystone
sudo pip install python-openstackclient


my_ip=$(ip a |grep 192.168.100 |awk '{print $2}' |awk -F '/' '{print $1}')
keystone-manage bootstrap --bootstrap-password s3cr3t \
  --bootstrap-admin-url http://$my_ip:35357/v3/ \
  --bootstrap-internal-url http://$my_ip:5000/v3/ \
  --bootstrap-public-url http://$my_ip:5000/v3/ \
  --bootstrap-region-id RegionOne

cat > ~/keystone.env <<EOF
export OS_USERNAME=admin
export OS_PASSWORD=s3cr3t
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_DOMAIN_ID=default
export OS_IDENTITY_API_VERSION=3
export OS_AUTH_URL=http://localhost:5000/v3
EOF
source ~/keystone.env

openstack project create service

openstack user create swift --password Sekr3tPass --project service
openstack role add admin --project service --user swift

openstack service create object-store --name swift --description "Swift Service"
openstack endpoint create swift public "http://swiftproxy:8080/v1/AUTH_\$(tenant_id)s"
openstack endpoint create swift internal "http://swiftproxy:8080/v1/AUTH_\$(tenant_id)s"

openstack role create SwiftOperator
openstack role create ResellerAdmin

# create a demo project and user (add this as a seperate script)
openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --password-prompt matt
openstack role create user
openstack role add --project demo --user matt user
openstack role add --project demo --user matt SwiftOperator
#openstack role add --project demo --user matt ResellerAdmin
