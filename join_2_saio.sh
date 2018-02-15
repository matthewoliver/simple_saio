ip1=${1:-192.168.100.10}
ip2=${2:-192.168.100.11}

sudo yum -y install vim net-tools telnet git unzip git wget

if [[ $(grep -c 'memcache_servers =' /etc/swift/proxy-server.conf) == 0 ]]
then
    sed -i "/use = egg:swift#memcache/a memcache_servers = $ip1:11211,$ip2:11211" /etc/swift/proxy-server.conf
else
    sed -i "s/memcache_servers = .*$/memcache_servers = $ip1:11211,$ip2:11211/g" /etc/swift/proxy-server.conf
fi

cat <<EOF > ~/bin/remakerings
#!/bin/bash

set -e

cd /etc/swift

rm -f *.builder *.ring.gz backups/*.builder backups/*.ring.gz

swift-ring-builder object.builder create 10 3 1
swift-ring-builder object.builder add r1z1-$ip1:6010/sdb1 1
swift-ring-builder object.builder add r1z2-$ip1:6020/sdb2 1
swift-ring-builder object.builder add r1z3-$ip1:6030/sdb3 1
swift-ring-builder object.builder add r1z4-$ip1:6040/sdb4 1
swift-ring-builder object.builder add r2z1-$ip2:6010/sdb1 1
swift-ring-builder object.builder add r2z2-$ip2:6020/sdb2 1
swift-ring-builder object.builder add r2z3-$ip2:6030/sdb3 1
swift-ring-builder object.builder add r2z4-$ip2:6040/sdb4 1
swift-ring-builder object.builder rebalance
swift-ring-builder object-1.builder create 10 2 1
swift-ring-builder object-1.builder add r1z1-$ip1:6010/sdb1 1
swift-ring-builder object-1.builder add r1z2-$ip1:6020/sdb2 1
swift-ring-builder object-1.builder add r1z3-$ip1:6030/sdb3 1
swift-ring-builder object-1.builder add r1z4-$ip1:6040/sdb4 1
swift-ring-builder object-1.builder add r2z1-$ip2:6010/sdb1 1
swift-ring-builder object-1.builder add r2z2-$ip2:6020/sdb2 1
swift-ring-builder object-1.builder add r2z3-$ip2:6030/sdb3 1
swift-ring-builder object-1.builder add r2z4-$ip2:6040/sdb4 1
swift-ring-builder object-1.builder rebalance
swift-ring-builder object-2.builder create 10 6 1
swift-ring-builder object-2.builder add r1z1-$ip1:6010/sdb1 1
swift-ring-builder object-2.builder add r1z1-$ip1:6010/sdb5 1
swift-ring-builder object-2.builder add r1z2-$ip1:6020/sdb2 1
swift-ring-builder object-2.builder add r1z2-$ip1:6020/sdb6 1
swift-ring-builder object-2.builder add r1z3-$ip1:6030/sdb3 1
swift-ring-builder object-2.builder add r1z3-$ip1:6030/sdb7 1
swift-ring-builder object-2.builder add r1z4-$ip1:6040/sdb4 1
swift-ring-builder object-2.builder add r1z4-$ip1:6040/sdb8 1
swift-ring-builder object-2.builder add r2z1-$ip2:6010/sdb1 1
swift-ring-builder object-2.builder add r2z1-$ip2:6010/sdb5 1
swift-ring-builder object-2.builder add r2z2-$ip2:6020/sdb2 1
swift-ring-builder object-2.builder add r2z2-$ip2:6020/sdb6 1
swift-ring-builder object-2.builder add r2z3-$ip2:6030/sdb3 1
swift-ring-builder object-2.builder add r2z3-$ip2:6030/sdb7 1
swift-ring-builder object-2.builder add r2z4-$ip2:6040/sdb4 1
swift-ring-builder object-2.builder add r2z4-$ip2:6040/sdb8 1
swift-ring-builder object-2.builder rebalance
swift-ring-builder container.builder create 10 3 1
swift-ring-builder container.builder add r1z1-$ip1:6011/sdb1 1
swift-ring-builder container.builder add r1z2-$ip1:6021/sdb2 1
swift-ring-builder container.builder add r1z3-$ip1:6031/sdb3 1
swift-ring-builder container.builder add r1z4-$ip1:6041/sdb4 1
swift-ring-builder container.builder add r2z1-$ip2:6011/sdb1 1
swift-ring-builder container.builder add r2z2-$ip2:6021/sdb2 1
swift-ring-builder container.builder add r2z3-$ip2:6031/sdb3 1
swift-ring-builder container.builder add r2z4-$ip2:6041/sdb4 1
swift-ring-builder container.builder rebalance
swift-ring-builder account.builder create 10 3 1
swift-ring-builder account.builder add r1z1-$ip1:6012/sdb1 1
swift-ring-builder account.builder add r1z2-$ip1:6022/sdb2 1
swift-ring-builder account.builder add r1z3-$ip1:6032/sdb3 1
swift-ring-builder account.builder add r1z4-$ip1:6042/sdb4 1
swift-ring-builder account.builder add r2z1-$ip2:6012/sdb1 1
swift-ring-builder account.builder add r2z2-$ip2:6022/sdb2 1
swift-ring-builder account.builder add r2z3-$ip2:6032/sdb3 1
swift-ring-builder account.builder add r2z4-$ip2:6042/sdb4 1
swift-ring-builder account.builder rebalance
EOF

if [[ $(ip a |grep -c $ip1) == 1 ]]; then
    remakerings
    rsync -Pavz /etc/swift/ vagrant@$ip2:/etc/swift/
fi

swift-init restart main
