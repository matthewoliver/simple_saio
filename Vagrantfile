Vagrant.configure(2) do |config|
  #config.vm.box = "ubuntu/xenial64"
  config.vm.box = "opensuse/Tumbleweed.x86_64"
  config.ssh.insert_key = false
  #config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  VMS = 4
  (0..VMS-1).each do |vm|
    config.vm.define "suse-saio#{vm}" do |g|
        g.vm.hostname = "suse-saio#{vm}"
    #config.vm.define "saio#{vm}" do |g|
    #    g.vm.hostname = "saio#{vm}"
        g.vm.network :private_network, type: "dhcp"
        g.vm.provider :virtualbox do |vb|
            vb.memory = 2048
            vb.cpus = 2
        end
        g.vm.provider :libvirt do |v|
             v.memory = 2048
             v.cpus = 2
        end
        config.vm.provision "file", source: "~/.ssh/id_rsa.pub", destination: "~/.ssh/me.pub"
        config.vm.provision "file", source: "saio.sh", destination: "~/saio.sh"
        config.vm.provision "shell", inline: "cat ~vagrant/.ssh/me.pub >> ~vagrant/.ssh/authorized_keys"
        config.vm.provision "file", source: "~/.ssh/id_rsa_vagrant", destination: "~/.ssh/id_rsa"
        config.vm.provision "file", source: "~/.ssh/id_rsa_vagrant.pub", destination: "~/.ssh/id_rsa.pub"
        config.vm.provision "shell", inline: "bash ~vagrant/saio.sh", privileged: false
        config.vm.provision "file", source: "setup_extras.sh", destination: "~/setup_extras.sh"
        config.vm.provision "shell", inline: "bash ~vagrant/setup_extras.sh", privileged: false
    end
  end
end
