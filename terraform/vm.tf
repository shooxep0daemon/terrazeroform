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
// Expose IP of first VM
output "buildmachineip" {
 value = google_compute_instance.instance_with_ip.network_interface.0.access_config.0.nat_ip
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
// Expose IP of first VM
output "runmachineip" {
 value = google_compute_instance.instance_with_ip2.network_interface.0.access_config.0.nat_ip
}
//wait 30 secs to complete creation
resource "time_sleep" "wait_30_seconds" {
  depends_on = [google_compute_instance.instance_with_ip2]

  create_duration = "30s"
}
//create inventory after 30 secs
resource "null_resource" "ansible_hosts_provisioner" {
   depends_on = [time_sleep.wait_30_seconds]
  provisioner "local-exec" {
    interpreter = ["/bin/bash" ,"-c"]
    command = <<EOT
      export terraform_buildmachineip=$(terraform output buildmachineip);
      echo buildip=$terraform_buildmachineip;
      export terraform_runmachineip=$(terraform output runmachineip);
      echo runip=$terraform_runmachineip;
      sed -i -e "s/builderip/$terraform_buildmachineip/g" ./inventory/hosts;
      sed -i -e "s/prodrunnerip/$terraform_runmachineip/g" ./inventory/hosts;
      sed -i -e 's/"//g' ./inventory/hosts;
      export ANSIBLE_HOST_KEY_CHECKING=False
    EOT
  }
}