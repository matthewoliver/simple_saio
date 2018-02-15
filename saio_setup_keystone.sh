keystone_host=${1:-localhost}
admin_user=${2:-swift}
admin_password=${3:-'Sekr3tPass'}
tenent_name=${4:-service}
reseller_prefix=${5:-AUTH}

# setup swift
sudo pip install keystonemiddleware
sed -i 's/ tempauth / authtoken keystoneauth /g' /etc/swift/proxy-server.conf
cat <<EOF >> /etc/swift/proxy-server.conf
[filter:authtoken]
paste.filter_factory = keystonemiddleware.auth_token:filter_factory
auth_host = $keystone_host
auth_port = 35357
auth_protocol = http
auth_uri = http://$keystone_host:5000/
admin_tenant_name = $tenent_name
admin_user = $admin_user
admin_password = $admin_password
delay_auth_decision = True
# cache = swift.cache
# include_service_catalog = False

[filter:keystoneauth]
use = egg:swift#keystoneauth
# reseller_prefix = $reseller_prefix
operator_roles = admin, SwiftOperator
reseller_admin_role = ResellerAdmin
EOF
