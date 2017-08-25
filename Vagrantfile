Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.ssh.insert_key = false
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  VMS = 1
  (0..VMS-1).each do |vm|
    config.vm.define "server#{vm}" do |g|
        g.vm.hostname = "server#{vm}"
        g.vm.network :private_network, type: "dhcp"
        g.vm.provider :virtualbox do |vb|
            vb.memory = 2048
            vb.cpus = 2
        end
        config.vm.provision "file", source: "~/.ssh/id_rsa.pub", destination: "~/.ssh/me.pub"
        config.vm.provision "file", source: "saio.sh", destination: "~/saio.sh"
        config.vm.provision "shell", inline: "cat ~vagrant/.ssh/me.pub >> ~vagrant/.ssh/authorized_keys"
        config.vm.provision "shell", inline: "bash ~vagrant/saio.sh", privileged: false
    end
  end
end
