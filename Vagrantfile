require "net/ssh"

module Net::SSH
  class << self
    alias_method :old_start, :start

    def start(host, username, opts)
      opts[:keys_only] = false
      self.old_start(host, username, opts)
    end
  end
end

Vagrant.configure("2") do |config|
  module Vagrant
    module Util
      class Platform
        class << self
          def solaris?
            true
          end
        end
      end
		end
	end
end

Vagrant.configure("2") do |config|
  shome=File.expand_path("..", __FILE__)

  config.ssh.shell = "bash"
  config.ssh.username = "ubuntu"
  config.ssh.forward_agent = true
  config.ssh.insert_key = false

  config.vm.provider "virtualbox" do |v, override|
    override.vm.box = "block:ubuntu"

    override.vm.synced_folder ENV['HOME'], '/vagrant', disabled: true
    override.vm.synced_folder '/data', '/data', type: "nfs"
    override.vm.synced_folder '/config', '/config', type: "nfs"

    override.vm.provision "shell", path: "#{shome}/script/cloud-init-wait", args: [], privileged: false

    v.linked_clone = true
    v.memory = 1024
    v.cpus = 2

    v.customize [ 'modifyvm', :id, '--nictype1', 'virtio' ]
    v.customize [ 'modifyvm', :id, '--paravirtprovider', 'kvm' ]
    v.customize [ 'modifyvm', :id, '--cableconnected1', 'on' ]
    v.customize [ 'modifyvm', :id, '--cableconnected2', 'on' ]

    v.customize [ 
      'storageattach', :id, 
      '--storagectl', 'SATA Controller', 
      '--port', 1, 
      '--device', 0, 
      '--type', 'dvddrive', 
      '--medium', "#{shome}/cidata.iso"
    ]
    v.customize [
      'storagectl', :id,
      '--name', 'SATA Controller',
      '--hostiocache', 'on'
    ]
  end

  config.vm.provider "aws" do |v, override|
    override.vm.box = "block:ubuntu"
    override.nfs.functional = false
    override.vm.synced_folder ENV['HOME'], '/vagrant', disabled: true
    override.vm.synced_folder '/data/cache/nodist', '/data/cache/nodist', type: "rsync", rsync__args: [ "-ia" ]
    override.vm.synced_folder ENV['AWS_SYNC'], ENV['AWS_SYNC'], type: "rsync", rsync__args: [ "-ia" ] if ENV['AWS_SYNC']

    override.vm.provision "shell", path: "#{shome}/script/cloud-init-wait", args: [], privileged: false

    v.region = ENV['AWS_DEFAULT_REGION']
    v.access_key_id = ENV['AWS_ACCESS_KEY_ID']
    v.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
    v.session_token = ENV['AWS_SESSION_TOKEN'] if ENV['AWS_SESSION_TOKEN']

    v.associate_public_ip = false
    v.ssh_host_attribute = :private_ip_address
    v.subnet_id = ENV['AWS_SUBNET'] if ENV['AWS_SUBNET']
    v.security_groups = [ ENV['AWS_SG'] ]

    v.keypair_name = ENV['AWS_KEYPAIR']
    v.instance_type = ENV['AWS_TYPE'] || 't2.small'
    v.block_device_mapping = [
      { 'DeviceName' => '/dev/sda1', 'Ebs.VolumeSize' => 40 },
      { 'DeviceName' => '/dev/sdb', 'VirtualName' => 'ephemeral0', },
      { 'DeviceName' => '/dev/sdc', 'VirtualName' => 'ephemeral1', },
      { 'DeviceName' => '/dev/sdd', 'VirtualName' => 'ephemeral2', },
      { 'DeviceName' => '/dev/sde', 'VirtualName' => 'ephemeral3', }
    ]
    v.tags = {
      'Provisioner' => 'vagrant'
    }
  end

  config.vm.define "default", primary: true do |machine|
    machine.vm.network "private_network", nic_type: 'virtio', ip: '172.28.128.11' unless ENV['AWS_SG']
  end

  config.vm.define "k8s-master", autostart: false do |machine|
    machine.vm.network "private_network", nic_type: 'virtio', ip: '172.28.128.12' unless ENV['AWS_SG']
  end

  config.vm.define "k8s-node1", autostart: false do |machine|
    machine.vm.network "private_network", nic_type: 'virtio', ip: '172.28.128.13' unless ENV['AWS_SG']
  end

  config.vm.define "k8s-node2", autostart: false do |machine|
    machine.vm.network "private_network", nic_type: 'virtio', ip: '172.28.128.13' unless ENV['AWS_SG']
  end
end
