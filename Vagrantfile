Vagrant.configure(2) do |config|
  config.vm.box = "centos/7"
  config.ssh.insert_key = false
  VMS = 3
  (0..VMS-1).each do |vm|
    config.vm.define "saio#{vm}" do |g|
        g.vm.hostname = "saio#{vm}"
        g.vm.network :private_network, type: "dhcp"
        g.vm.provider :virtualbox do |vb|
            vb.memory = 2048
            vb.cpus = 2
        end
        config.vm.provision "file", source: "~/.ssh/id_rsa.pub", destination: "~/.ssh/me.pub"
        config.vm.provision "file", source: "saio.sh", destination: "~/saio.sh"
        config.vm.provision "shell", inline: "cat ~vagrant/.ssh/me.pub >> ~vagrant/.ssh/authorized_keys"
        config.vm.provision "file", source: "~/.ssh/id_rsa_vagrant", destination: "~/.ssh/id_rsa"
        config.vm.provision "file", source: "~/.ssh/id_rsa_vagrant.pub", destination: "~/.ssh/id_rsa.pub"
        config.vm.provision "shell", inline: "bash ~vagrant/saio.sh", privileged: false
    end
  end
end
