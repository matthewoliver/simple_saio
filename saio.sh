#!/bin/bash
DEBIAN=0
REDHAT=1
SUSE=2
SIZE=1
UNIT_TESTS=0
BUILD_LIBERASURECODE=1
SETUP_VENV=1
branch=${1:-master}
PIP="pip"

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
  elif [ $DISTRO -eq $REDHAT ]
  then
    sudo yum install -y gcc make autoconf automake libtool
  else
    sudo zypper --gpg-auto-import-keys install -y gcc make autoconf automake libtool
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
                       python-netifaces python-pip python-dnspython \
                       python-mock
  users_grp="${USER}"
elif [ $DISTRO -eq $REDHAT ]
then
  source /etc/os-release
  sudo yum update
  sudo yum install -y epel-release
  if [ $VERISON -lt 8 ]
  then
    sudo yum install -y curl gcc memcached rsync sqlite xfsprogs git-core \
                          libffi-devel xinetd \
                          openssl-devel python-setuptools \
                          python-coverage python-devel python-nose \
                          pyxattr python-eventlet \
                          python-greenlet python-paste-deploy \
                          python-netifaces python-pip python-dns \
                          python-mock
  else
	PIP="pip2"
    sudo yum install -y curl gcc memcached rsync sqlite xfsprogs git-core \
                        libffi-devel xinetd rsync-daemon \
                        openssl-devel python2-setuptools python3-setuptools \
						python2-coverage python2-devel python2-nose \
						python3-coverage python3-devel python3-nose \
						python3-eventlet python3-greenlet python3-paste-deploy \
						python3-netifaces python2-pip python3-pip python3-dns \
						python2-mock
  fi
  users_grp="${USER}"
else
  sudo zypper --gpg-auto-import-keys install -y \
                      curl gcc memcached rsync sqlite3 xfsprogs git-core \
                      libffi-devel liberasurecode-devel python2-setuptools \
                      libopenssl-devel zlib-devel python3 python-devel python3-devel
  sudo zypper --gpg-auto-import-keys install -y \
                      python2-pip python3-coverage python3-devel \
                      python3-nose python3-xattr python3-eventlet \
                      python3-greenlet python3-netifaces python3-pip \
                      python3-dnspython python3-mock python3-dbm
  users_grp="users"
fi

if [ $BUILD_LIBERASURECODE -gt 0 ]
then
  build_liberasurecode
else
  if [ $DISTRO -eq $DEBIAN ]
  then
    sudo apt-get install -y liberasurecode-dev
  elif [ $DISTRO -eq $REDHAT ]
  then
    sudo yum install -y liberasurecode-devel
  else
    sudo zypper install -y liberasurecode-devel
  fi
fi

# Using loopback device
sudo mkdir -p /srv
sudo truncate -s $(echo $SIZE)GB /srv/swift-disk
sudo mkfs.xfs /srv/swift-disk

# Add to fstab
if [ $(grep -c "/srv/swift-disk" /etc/fstab) -gt 0 ]
then
    #sudo sed -i 's|^/srv/swift-disk .*$|/srv/swift-disk /mnt/sdb1 xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0|' /etc/fstab
    sudo sed -i 's|^/srv/swift-disk .*$|/srv/swift-disk /mnt/sdb1 xfs loop,noatime,nodiratime,logbufs=8 0 0|' /etc/fstab
else
    #sudo su -c "echo '/srv/swift-disk /mnt/sdb1 xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0' >> /etc/fstab"
    sudo su -c "echo '/srv/swift-disk /mnt/sdb1 xfs loop,noatime,nodiratime,logbufs=8 0 0' >> /etc/fstab"
fi

# create the mountpoints 
sudo mkdir -p /mnt/sdb1
sudo mount /mnt/sdb1
sudo mkdir -p /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4
sudo chown ${USER}:${users_grp} /mnt/sdb1/*
for x in {1..4}; do sudo ln -s /mnt/sdb1/$x /srv/$x; done
sudo mkdir -p /srv/1/node/sdb1 /srv/1/node/sdb5 \
              /srv/2/node/sdb2 /srv/2/node/sdb6 \
              /srv/3/node/sdb3 /srv/3/node/sdb7 \
              /srv/4/node/sdb4 /srv/4/node/sdb8 \
              /var/run/swift
sudo chown -R ${USER}:${users_grp} /var/run/swift
# **Make sure to include the trailing slash after /srv/$x/**
for x in {1..4}; do sudo chown -R ${USER}:${users_grp} /srv/$x/; done

setup_saio_mounts=/usr/local/bin/setup_saio_mounts.sh
sudo mkdir -p $(dirname $setup_saio_mounts)
sudo touch $setup_saio_mounts
sudo chmod +x $setup_saio_mounts
cat << EOF |sudo tee $setup_saio_mounts
mkdir -p /var/cache/swift /var/cache/swift2 /var/cache/swift3 /var/cache/swift4
chown ${USER}:${users_grp} /var/cache/swift*
mkdir -p /var/run/swift
chown ${USER}:${users_grp} /var/run/swift
EOF
sudo $setup_saio_mounts

if [ $DISTRO -eq $DEBIAN ]
then
  rc_local="/etc/rc.local"
elif [ $DISTRO -eq $REDHAT ]
then
  rc_local="/etc/rc.d/rc.local"
else
  rc_local="/etc/init.d/boot.local"
fi 
if [ -e $rc_local ] && [ $(grep -c "$setup_saio_mounts" $rc_local) -eq 0 ]
then
  if [ $(grep -c "^exit 0" $rc_local) -gt 0 ]
  then
    sudo sed -i "/exit 0/i$setup_saio_mounts\n" $rc_local
  else
    echo "$setup_saio_mounts" |sudo tee --append $rc_local
  fi
fi

# upgrade pip and tox
#sudo pip install pip tox git-review virtualenv setuptools --upgrade
sudo $PIP install pip tox --upgrade
sudo $PIP install setuptools --upgrade
sudo $PIP install tox git-review virtualenv --upgrade

if [ $SETUP_VENV -gt 0 ]
then
  mkdir -p  $HOME/venv
  virtualenv $HOME/venv
  source $HOME/venv/bin/activate
fi

# get the code
cd $HOME; git clone https://github.com/openstack/python-swiftclient.git
if [ $SETUP_VENV -gt 0 ]
then
  PIP="$PIP"
else
  PIP="sudo $PIP"
fi
cd $HOME/python-swiftclient; $PIP install -e . ; cd -

git clone https://github.com/openstack/swift.git
if [ $DISTRO -eq $SUSE ]
then
  cd $HOME/swift; git checkout $branch; $PIP install --no-binary cryptography -r requirements.txt;
else
  cd $HOME/swift; git checkout $branch; $PIP install -r requirements.txt;
fi
$PIP install -e .
cd -

if [ $DISTRO -eq $REDHAT ]
then
  $PIP install -U xattr
elif
  [ $DISTRO -eq $SUSE ]
then
  $PIP install ipaddress
fi

$PIP install -r swift/test-requirements.txt

# setup rsync
sudo cp $HOME/swift/doc/saio/rsyncd.conf /etc/
sudo sed -i "s/<your-user-name>/${USER}/" /etc/rsyncd.conf
if [ $DISTRO -eq $DEBIAN ]
then
  sudo sed -i 's/^RSYNC_ENABLE=.*$/RSYNC_ENABLE=true/' /etc/default/rsync
  sudo service rsync restart
elif [ $DISTRO -eq $REDHAT ]
then
  sudo sed -i 's/^disable =.*$/disable = no/' /etc/xinetd.d/rsync
  sudo setenforce Permissive
  sudo systemctl restart xinetd.service
  sudo systemctl enable rsyncd.service
  sudo systemctl start rsyncd.service
else
  sudo systemctl enable rsyncd.service
  sudo systemctl start rsyncd.service
fi

# Memcache
sudo systemctl enable memcached.service
sudo systemctl start memcached.service

# Syslog
sudo cp $HOME/swift/doc/saio/rsyslog.d/10-swift.conf /etc/rsyslog.d/
sudo sed -i  's/^$PrivDropToGroup .*/$PrivDropToGroup adm/' /etc/rsyslog.conf
sudo mkdir -p /var/log/swift
sudo chown -R syslog.adm /var/log/swift
sudo chmod -R g+w /var/log/swift
sudo service rsyslog restart

# Configure each node
sudo rm -rf /etc/swift

cd $HOME/swift/doc; sudo cp -r saio/swift /etc/swift; cd -
sudo chown -R ${USER}:${users_grp} /etc/swift

find /etc/swift/ -name \*.conf | xargs sudo sed -i "s/<your-user-name>/${USER}/"

# setup scripts for runnning swift
mkdir -p $HOME/bin
cd $HOME/swift/doc; cp -r saio/bin/* $HOME/bin/; cd -
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
exit 0
