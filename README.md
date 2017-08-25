This is a simple vagrant + shell script that will setup a basic OpenStack Swift All In One (SAIO).

As per: https://docs.openstack.org/swift/latest/development_saio.html

The script should work for debian/ubuntu or redhat/centos. But it's defaulting to debian/ubunut.
You can change this at the top of the file. I could just add a switch, but like I said it's simple :P

By default it'll also build liberasurecode from source, but if you turn this off, it'll install packages.

It's best to go with vagrant:

  vagrant up

And you'll have a virtualbox SAIO ubuntu server.

If you want multiple, just change the number of VMs in the Vagrantfile, why, more then one.. In case you
want to review a bunch of Swift patches for us ;)

Other people have better SAIO's, there are chef and ansible run ones.. but I wrote this script back when
I had cloud access at RackSpace, so would just spin up, scp it on and have a SAIO.. see simple. Now's it's
grown a Vagrantfile so its even easier.
