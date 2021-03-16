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
      cat <<EOF >./inventory/hosts
[builderhost] 
$(terraform output buildmachineip)
[prodhost]
$(terraform output runmachineip)
EOF
      export ANSIBLE_HOST_KEY_CHECKING=False
    EOT
  }
}
// run playbook on created hosts
resource "null_resource" "ansible_playbook_provisioner" {
  depends_on = [null_resource.ansible_hosts_provisioner]
  provisioner "local-exec" {
    command = "ansible-playbook -u ${var.ssh_username} --vault-password-file 'vault_pass' --private-key ${var.ssh_pub_key_path} -i ./inventory/hosts roles.yml"
  }
}