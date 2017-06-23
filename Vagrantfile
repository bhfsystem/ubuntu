require 'socket'

ci_script = "#{ENV['_limbo_home']}/script/cloud-init-bootstrap"

Vagrant.configure("2") do |config|
  config.ssh.shell = "bash"
  config.ssh.username = "ubuntu"
  config.ssh.forward_agent = true
  config.ssh.insert_key = false
  config.ssh.keys_only = false

  (0..9).each do |d|
    nm_vagrant = "#{Socket.gethostname}-v#{d}"
    config.vm.define nm_vagrant, primary: (d == 0), autostart: (d == 0) do |vagrant|
      vagrant.vm.provider "docker" do |docker|
        docker.name = nm_vagrant
        config.vm.hostname = nm_vagrant
      end
    end
  end

  config.vm.provider "docker" do |v, override|
    nm_image = "docker.nih/block:#{Dir.pwd.split("/")[-1]}"

    override.vm.synced_folder ENV['HOME'], '/vagrant', disabled: true
    override.vm.synced_folder '/data', '/data'
    override.vm.synced_folder '/config', '/config'

    override.ssh.guest_port = "2222"
    override.vm.network "forwarded_port", id: "ssh", disabled: true, host: 2222, guest: 2222

    v.docker_network = "ubuntu_default"
    v.image = nm_image
    v.has_ssh = true
  end

  config.vm.provider "aws" do |v, override|
    pth_sync = ENV['AWS_SYNC'] || ''
    nm_env = "build"
    nm_app = "vagrant"
    pth_userdata = ""
    nm_ami = ENV['AWS_AMI'] || 'id-aws-ami-not-set'
    nm_type = ENV['AWS_TYPE'] || "t2.nano"

    override.vm.synced_folder ENV['HOME'], '/vagrant', disabled: true
    override.vm.synced_folder '/data/cache/nodist', '/data/cache/nodist', type: "rsync", rsync__args: [ "-ia" ], rsync__verbose: true
    override.vm.synced_folder pth_sync, pth_sync, type: "rsync", rsync__args: [ "-ia" ], rsync__verbose: true if File.directory?(pth_sync)

    override.vm.box = ENV['SOURCE_NAME'] ? ENV['SOURCE_NAME'] : "block:ubuntu"

    override.vm.provision "shell", path: ci_script, args: [], privileged: true

    if File.exists?(pth_userdata)
      v.user_data = File.read(pth_userdata)
    end

    v.iam_instance_profile_name = ENV['AWS_IAM'] || "id-iam-role-not-set"
    v.region_config ENV['AWS_DEFAULT_REGION'], 
      ami: nm_ami, instance_type: nm_type

    v.tags = {
      "ManagedBy" => "vagrant",
      "Env" => nm_env,
      "App" => nm_app,
      "Service" => Dir.pwd.split("/")[-1],
      "Color" => "vagrant"
    }
  end

  config.vm.provider "virtualbox" do |v, override|
    override.vm.box = ENV['SOURCE_NAME'] ? ENV['SOURCE_NAME'] : "block:ubuntu"

    override.vm.synced_folder ENV['HOME'], '/vagrant', disabled: true
    override.vm.synced_folder '/data', '/data', type: "nfs"
    override.vm.synced_folder '/config', '/config', type: "nfs"

    override.vm.provision "shell", path: ci_script, args: [], privileged: true

    override.vm.network "private_network", ip: '172.28.128.10', nic_type: 'virtio'

    v.memory = 1024
    v.cpus = 2

    v.customize [ 
      'storageattach', :id, 
      '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, 
      '--type', 'dvddrive', '--medium', "#{ENV['_base_home']}/cidata.vagrant.iso"
    ]
  end
end
