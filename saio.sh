#!/bin/bash
DEBIAN=0
REDHAT=1
SUSE=2
SIZE=1
UNIT_TESTS=0
BUILD_LIBERASURECODE=1
branch=${1:-master}
LOCALHOST=0
IP_SUBNET="192.168.100"

DISTRO=$REDHAT

function build_liberasurecode() {
  if [ ${BUILD_LIBERASURECODE} -eq 0 ]
  then
    return
  fi

  echo "== Building liberasurecode =="
  cd $HOME
  git clone https://github.com/openstack/liberasurecode
  cd liberasurecode

  if [ $DISTRO -eq $DEBIAN ]
  then
    sudo apt-get install -y build-essential autoconf automake libtool
  else
    sudo yum install -y gcc make autoconf automake libtool
  fi

  ./autogen.sh
  ./configure
  make
  sudo make install

  echo '/usr/local/lib' |sudo tee /etc/ld.so.conf.d/lib_ec.conf
  sudo ldconfig
}

if [ $DISTRO -eq $DEBIAN ]
then
  sudo apt-get update
  sudo apt-get install -y curl gcc memcached rsync sqlite3 xfsprogs \
                      git-core libffi-dev python-setuptools \
                      libssl-dev
  sudo apt-get install -y python-coverage python-dev python-nose \
                       python-xattr python-eventlet \
                       python-greenlet python-pastedeploy \
                       thon-netifaces python-pip python-dnspython \
                       python-mock
else
  sudo yum update
  sudo yum install -y epel-release
  sudo yum install -y curl gcc memcached rsync sqlite xfsprogs git-core \
                      libffi-devel xinetd \
                      openssl-devel python-setuptools \
                      python-coverage python-devel python-nose \
                      pyxattr python-eventlet \
                      python-greenlet python-paste-deploy \
                      python-netifaces python-pip python-dns \
                      python-mock 

fi

if [ $BUILD_LIBERASURECODE -gt 0 ]
then
  build_liberasurecode
else
  if [ $DISTRO -eq $DEBIAN ]
  then
    sudo apt-get install -y liberasurecode-dev
  else
    sudo yum install -y liberasurecode-devel
  fi
fi

# Using loopback device
sudo mkdir /srv
sudo truncate -s $(echo $SIZE)GB /srv/swift-disk
sudo mkfs.xfs /srv/swift-disk

# Add to fstab
if [ $(grep -c "/srv/swift-disk" /etc/fstab) -gt 0 ]
then
    sudo sed -i 's|^/srv/swift-disk .*$|/srv/swift-disk /mnt/sdb1 xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0|' /etc/fstab
else
    sudo su -c "echo '/srv/swift-disk /mnt/sdb1 xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0' >> /etc/fstab"
fi

# create the mountpoints 
sudo mkdir -p /mnt/sdb1
sudo mount /mnt/sdb1
sudo mkdir -p /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4
sudo chown ${USER}:${USER} /mnt/sdb1/*
for x in {1..4}; do sudo ln -s /mnt/sdb1/$x /srv/$x; done
sudo mkdir -p /srv/1/node/sdb1 /srv/1/node/sdb5 \
              /srv/2/node/sdb2 /srv/2/node/sdb6 \
              /srv/3/node/sdb3 /srv/3/node/sdb7 \
              /srv/4/node/sdb4 /srv/4/node/sdb8 \
              /var/run/swift
sudo chown -R ${USER}:${USER} /var/run/swift
# **Make sure to include the trailing slash after /srv/$x/**
for x in {1..4}; do sudo chown -R ${USER}:${USER} /srv/$x/; done

setup_saio_mounts=/usr/local/bin/setup_saio_mounts.sh
sudo mkdir -p $(dirname $setup_saio_mounts)
sudo touch $setup_saio_mounts
sudo chmod +x $setup_saio_mounts
cat << EOF |sudo tee $setup_saio_mounts
mkdir -p /var/cache/swift /var/cache/swift2 /var/cache/swift3 /var/cache/swift4
chown ${USER}:${USER} /var/cache/swift*
mkdir -p /var/run/swift
chown ${USER}:${USER} /var/run/swift
EOF
sudo $setup_saio_mounts

if [ $DISTRO -eq $DEBIAN ]
then
  if [ -e /etc/rc.local ] && [ $(grep -c "$setup_saio_mounts" /etc/rc.local) -eq 0 ]
  then
    if [$(grep -c "^exit 0" /etc/rc.local) -gt 0]
    then
      sudo sed -i "/exit 0/i$setup_saio_mounts\n" /etc/rc.local
    else
      echo "$setup_saio_mounts" | sudo tee --append /etc/rc.local
    fi
  fi
elif [ $DISTRO -eq $REDHAT ]
then
  if [ -e /etc/rc.d/rc.local ] && [ $(grep -c "$setup_saio_mounts" /etc/rc.d/rc.local) -eq 0 ]
  then
    if [$(grep -c "^exit 0" /etc/rc.d/rc.local) -gt 0]
    then
      sudo sed -i "/exit 0/i$setup_saio_mounts\n" /etc/rc.d/rc.local
    else
      echo "$setup_saio_mounts" |sudo tee --append /etc/rc.d/rc.local
    fi
  fi
fi 

# upgrade pip and tox
sudo pip install pip tox setuptools --upgrade

# get the code
cd $HOME; git clone https://github.com/openstack/python-swiftclient.git
cd $HOME/python-swiftclient; sudo pip install -e . ; cd -

git clone https://github.com/openstack/swift.git
cd $HOME/swift; git checkout $branch; sudo pip install --no-binary cryptography -r requirements.txt; sudo pip install -e . ; cd -

if [ $DISTRO -eq $REDHAT ]
then
  sudo pip install -U xattr
fi

sudo pip install -r swift/test-requirements.txt

# setup rsync
sudo cp $HOME/swift/doc/saio/rsyncd.conf /etc/
sudo sed -i "s/<your-user-name>/${USER}/" /etc/rsyncd.conf
if [ $DISTRO -eq $DEBIAN ]
then
  sudo sed -i 's/^RSYNC_ENABLE=.*$/RSYNC_ENABLE=true/' /etc/default/rsync
  sudo service rsync restart
else
  sudo sed -i 's/^disable =.*$/disable = no/' /etc/xinetd.d/rsync
  sudo setenforce Permissive
  sudo systemctl restart xinetd.service
  sudo systemctl enable rsyncd.service
  sudo systemctl start rsyncd.service
fi

# Memcache
sudo systemctl enable memcached.service
sudo systemctl start memcached.service

# Syslog
sudo cp $HOME/swift/doc/saio/rsyslog.d/10-swift.conf /etc/rsyslog.d/
sed -i  's/^$PrivDropToGroup .*/$PrivDropToGroup adm/' /etc/rsyslog.conf
sudo mkdir -p /var/log/swift
sudo chown -R syslog.adm /var/log/swift
sudo chmod -R g+w /var/log/swift
sudo service rsyslog restart

# Configure each node
sudo rm -rf /etc/swift

cd $HOME/swift/doc; sudo cp -r saio/swift /etc/swift; cd -
sudo chown -R ${USER}:${USER} /etc/swift

find /etc/swift/ -name \*.conf | xargs sudo sed -i "s/<your-user-name>/${USER}/"
if [[ $LOCALHOST == 0 ]]
then
    sed -i 's/bind_ip = 127.0.0../bind_ip = 0.0.0.0/g' /etc/swift/proxy-server.conf
    sed -i 's/bind_ip = 127.0.0../bind_ip = 0.0.0.0/g' /etc/swift/account-server/*
    sed -i 's/bind_ip = 127.0.0../bind_ip = 0.0.0.0/g' /etc/swift/container-server/*
    sed -i 's/bind_ip = 127.0.0../bind_ip = 0.0.0.0/g' /etc/swift/object-server/*
fi

# setup scripts for runnning swift
cd $HOME/swift/doc; cp -r saio/bin $HOME/bin; cd -
chmod +x $HOME/bin/*

# We are using loopback so...
sed -i "s/dev\/sdb1/srv\/swift-disk/" $HOME/bin/resetswift

# install sample configuration for running tests
cp $HOME/swift/test/sample.conf /etc/swift/test.conf
echo "export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf" >> $HOME/.bashrc

# Add bin directory to PATH
echo "export PATH=${PATH}:$HOME/bin" >> $HOME/.bashrc
. $HOME/.bashrc

# Make the rings
if [[ $LOCALHOST == 0 ]]
then
    if [[ $USER == 'vagrant' ]]
    then
        sudo ifup eth1
    fi
    my_ip=$(ip a |grep $IP_SUBNET |awk '{print $2}' |awk -F '/' '{print $1}')
    sed -i "s/127.0.0../$my_ip/g" $HOME/bin/remakerings
    sed -i "/use = egg:swift#memcache/a memcache_servers = $my_ip:11211" /etc/swift/proxy-server.conf
    sudo echo "$my_up swiftproxy" >> /etc/hosts
fi
$HOME/bin/remakerings

. $HOME/.bashrc


# Test rsync
echo -e "Testing Rsync\n================="
rsync rsync://pub@localhost/

if [ $UNIT_TESTS -eq 1 ]
then
    #$HOME/swift/.unittests
    cd $HOME/swift
    tox
fi

startmain

if [ $UNIT_TESTS -eq 1 ]
then
    $HOME/swift/.functests
    $HOME/swift/.probetests
fi

if [ $(ps -eaf |grep -c "\/swift") -le 1 ]
then
  $HOME/bin/startmain
  $HOME/bin/startrest
fi

if [[ $LOCALHOST == 1 ]]
then
  my_ip="127.0.0.1"
fi

cat <<EOF > ~/swiftclient_v1.env
export ST_AUTH=http://$my_ip:8080/auth/v1.0
# Admin
export ST_USER=test:tester
export ST_KEY=testing
# USER
#export ST_USER=test:tester3
#export ST_KEY=testing3
EOF

if [[ $LOCALHOST == 0 ]]
then
    cat <<EOF > ~/.ssh/config
Host $IP_SUBNET.*
   StrictHostKeyChecking no
   UserKnownHostsFile=/dev/null
EOF
    chmod 600 ~/.ssh/config
fi
exit 0
