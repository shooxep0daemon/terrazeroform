resource "google_compute_address" "static" {
  name = "ipv4-address"
}

resource "google_compute_firewall" "default" {
 name    = "drone-firewall"
 network = "default"

 allow {
   protocol = "icmp"
 }

 allow {
   protocol = "tcp"
   ports    = ["80", "8000", "9000"]
 }
 source_ranges = ["0.0.0.0/0"]
 source_tags = ["web"]

}

// Define VM resource
resource "google_compute_instance" "instance_with_ip" {
    name         = "build-vm"
    machine_type = "e2-medium" // 2vCPU, 4GB RAM
    zone         = "${var.zone}"

    boot_disk {
        initialize_params{
            image = "ubuntu-os-cloud/ubuntu-2004-lts"
        }
    }

    metadata = {
        ssh-keys = "${var.ssh_username}:${file(var.ssh_pub_key_path)}"
    }    
    
    network_interface {
        network = "default"
        access_config {
            #nat_ip = "${google_compute_address.static.address}"
        }
    }
}

resource "google_compute_instance" "instance_with_ip2" {
    name         = "prod-vm"
    machine_type = "e2-medium" // 2vCPU, 4GB RAM
    zone         = "${var.zone}"

    boot_disk {
        initialize_params{
            image = "ubuntu-os-cloud/ubuntu-2004-lts"
        }
    }

    metadata = {
        ssh-keys = "${var.ssh_username}:${file(var.ssh_pub_key_path)}"
    }    
    
    network_interface {
        network = "default"
        access_config {
            #nat_ip = "${google_compute_address.static.address}"
        }
    }
}

// Expose IP of VMs
output "buildmachineip" {
 value = "${google_compute_instance.instance_with_ip.network_interface.0.access_config.0.nat_ip}"
}
output "runmachineip" {
 value = "${google_compute_instance.instance_with_ip2.network_interface.0.access_config.0.nat_ip}"
}
//create inventory
resource "null_resource" "ansible_hosts_provisioner" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash" ,"-c"]
    command = <<EOT
      export buildmachineip=$(terraform output buildmachineip);
      echo $buildmachineip;
      export runmachineip=$(terraform output runmachineip);
      echo $runmachineip;
      sed -i -e "s/builder_ip/$buildmachineip/g" ./inventory/hosts;
      sed -i -e "s/prodrunner_ip/$runmachinei/g" ./inventory/hosts;
      sed -i -e 's/"//g' ./inventory/hosts;
      export ANSIBLE_HOST_KEY_CHECKING=False
    EOT
  }
}