output "master_public_ip" {
  description = "Adresse IP publique du master"
  value       = azurerm_public_ip.master_public_ip.ip_address
}

output "master_private_ip" {
  description = "Adresse IP privée du master"
  value       = azurerm_network_interface.master_nic.ip_configuration[0].private_ip_address
}

output "worker_public_ips" {
  description = "Adresses IP publiques des workers"
  value       = azurerm_public_ip.worker_public_ip[*].ip_address
}

output "worker_private_ips" {
  description = "Adresses IP privées des workers"
  value       = [for nic in azurerm_network_interface.worker_nic : nic.ip_configuration[0].private_ip_address]
}

output "ssh_command" {
  description = "Commande SSH pour se connecter au master"
  value       = "ssh -i hadoop_ssh_key.pem ${var.admin_username}@${azurerm_public_ip.master_public_ip.ip_address}"
}

output "ssh_worker1_command" {
  description = "Commande SSH pour se connecter au worker1"
  value       = "ssh -i hadoop_ssh_key.pem ${var.admin_username}@${azurerm_public_ip.worker_public_ip[0].ip_address}"
}

output "ssh_worker2_command" {
  description = "Commande SSH pour se connecter au worker2"
  value       = "ssh -i hadoop_ssh_key.pem ${var.admin_username}@${azurerm_public_ip.worker_public_ip[1].ip_address}"
}

output "private_key_location" {
  description = "Emplacement de la clé privée SSH"
  value       = "${path.module}/hadoop_ssh_key.pem"
}

output "cluster_info" {
  description = "Informations du cluster"
  value = <<-EOT
    
    === HADOOP CLUSTER INFORMATION ===
    
    Master Node:
      - Public IP: ${azurerm_public_ip.master_public_ip.ip_address}
      - Private IP: ${azurerm_network_interface.master_nic.ip_configuration[0].private_ip_address}
      - Hostname: hadoop-master
    
    Worker 1:
      - Public IP: ${azurerm_public_ip.worker_public_ip[0].ip_address}
      - Private IP: ${azurerm_network_interface.worker_nic[0].ip_configuration[0].private_ip_address}
      - Hostname: hadoop-worker1
    
    Worker 2:
      - Public IP: ${azurerm_public_ip.worker_public_ip[1].ip_address}
      - Private IP: ${azurerm_network_interface.worker_nic[1].ip_configuration[0].private_ip_address}
      - Hostname: hadoop-worker2
    
    Network: 10.0.1.0/24 (hadoop-subnet)
    
    Web UIs (après démarrage des services):
      - HDFS NameNode: http://${azurerm_public_ip.master_public_ip.ip_address}:9870
      - YARN ResourceManager: http://${azurerm_public_ip.master_public_ip.ip_address}:8088
    
    Pour finaliser l'installation:
      1. ssh -i hadoop_ssh_key.pem ${var.admin_username}@${azurerm_public_ip.master_public_ip.ip_address}
      2. sudo bash /home/${var.admin_username}/complete_setup.sh
    
  EOT
}
