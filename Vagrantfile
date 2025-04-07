# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
    # The most common configuration options are documented and commented below.
    # For a complete reference, please see the online documentation at
    # https://developer.hashicorp.com/vagrant/docs
    
    config.vm.box = "ubuntu/jammy64"
  
    config.vm.provider "virtualbox" do |vb|
      vb.memory = "1536"
      # graphicscontroller vmsvga
      vb.customize ['modifyvm', :id, '--graphicscontroller', 'vmsvga']
    end

    # HTTP
    config.vm.network "forwarded_port", guest: 80, host: 8080
    # HTTPS
    config.vm.network "forwarded_port", guest: 443, host: 8443
    # debug
    config.vm.network "forwarded_port", guest: 8000, host: 8000
    # Postgres
    config.vm.network "forwarded_port", guest: 5432, host: 5432
  
    WEB2PY_V2 = "v2.27.1"
    config.vm.define "v2", autostart: false do |v2|
      v2.vm.provider "virtualbox" do |vb|
        vb.name = "web2py-v2"
      end
      
      v2.vm.synced_folder "#{WEB2PY_V2}/", "/vagrant/#{WEB2PY_V2}",
        owner: "www-data", group: "www-data", create: true,
        mount_options: ["uid=33", "gid=33", "dmode=775", "fmode=664"]
  
      v2.vm.provision "shell", path: "setup-web2py-ubuntu.sh",
        args: ["dev", WEB2PY_V2, "vagrant", WEB2PY_V2]
    end
    
    WEB2PY_V3 = "v3.0.11"
    config.vm.define "v3" do |v3|
      v3.vm.provider "virtualbox" do |vb|
        vb.name = "web2py-v3"
      end
      
      v3.vm.synced_folder "#{WEB2PY_V3}/", "/vagrant/#{WEB2PY_V3}",
        owner: "www-data", group: "www-data", create: true,
        mount_options: ["uid=33", "gid=33", "dmode=775", "fmode=664"]
  
      v3.vm.provision "shell", path: "setup-web2py-ubuntu.sh",
        args: ["dev", WEB2PY_V3, "vagrant", WEB2PY_V3]
    end
  end
  