keystone_vms = 2
VMS = 2

Vagrant.configure(2) do |config|
  config.vm.box = "centos/7"
  config.ssh.insert_key = false
  (0..VMS-1).each do |vm|
    config.vm.define "saio#{vm}" do |g|
        g.vm.hostname = "saio#{vm}"
        g.vm.network :private_network, ip: "192.168.100.1#{vm}"
        g.vm.provider :virtualbox do |vb|
            vb.memory = 2048
            vb.cpus = 2
        end
        config.vm.provision "put_installer", type: "file", source: "saio.sh", destination: "~/saio.sh"
        config.vm.provision "put_join_saio", type: "file", source: "join_2_saio.sh", destination: "~/join_2_saio.sh"
        config.vm.provision "put_saio_keysone", type: "file", source: "saio_setup_keystone.sh", destination: "~/saio_setup_keystone.sh"
        config.vm.provision "file", source: "~/.ssh/id_rsa.pub", destination: "~/.ssh/me.pub"
        config.vm.provision "shell", inline: "cat ~vagrant/.ssh/me.pub >> ~vagrant/.ssh/authorized_keys"
        config.vm.provision "file", source: "~/.ssh/id_rsa_vagrant", destination: "~/.ssh/id_rsa"
        config.vm.provision "file", source: "~/.ssh/id_rsa_vagrant.pub", destination: "~/.ssh/id_rsa.pub"
        config.vm.provision "shell", inline: "cat ~vagrant/.ssh/id_rsa.pub >> ~vagrant/.ssh/authorized_keys"
        config.vm.provision "run_installer", type: "shell", inline: "bash ~vagrant/saio.sh", privileged: false
    end
  end

  (0..keystone_vms-1).each do |vm|
    config.vm.define "keystone#{vm}" do |g|
        g.vm.hostname = "keystone#{vm}"
        g.vm.network :private_network, ip: "192.168.100.2#{vm}"
        g.vm.provider :virtualbox do |vb|
            vb.memory = 2048
            vb.cpus = 2
        end
        config.vm.provision "put_installer", type: "file", source: "setup_keystone.sh", destination: "~/setup_keystone.sh"
        config.vm.provision "put_join_saio", type: "shell", inline: "echo not an saio"
        config.vm.provision "put_saio_keysone", type: "shell", inline: "echo not an saio"
        config.vm.provision "run_installer", type: "shell", inline: "bash ~vagrant/setup_keystone.sh", privileged: false
    end
  end
end
