Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/jammy64"

  nodes = {
    "ansible-control" => "192.168.56.10",
    "k8s-master"      => "192.168.56.11",
    "worker1"         => "192.168.56.12",
    "worker2"         => "192.168.56.13",
    "worker3"         => "192.168.56.14",
    "edge-gateway"    => "192.168.56.15"
  }

  nodes.each do |name, ip|

    config.vm.define name do |node|

      node.vm.hostname = name

      node.vm.network "private_network", ip: ip

      node.vm.provider "virtualbox" do |vb|

        vb.name = name

        vb.memory = case name
        when "k8s-master"
          4096
        when "worker1", "worker2", "worker3"
          3072
        when "ansible-control"
          2048
        when "edge-gateway"
          1024
        else
          1024
        end

        vb.cpus = 2
      end
    end   
  end     
end