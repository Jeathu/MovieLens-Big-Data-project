terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "movielens" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "hadoop_vnet" {
  name                = "hadoop-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.movielens.location
  resource_group_name = azurerm_resource_group.movielens.name
}

# Subnet
resource "azurerm_subnet" "hadoop_subnet" {
  name                 = "hadoop-subnet"
  resource_group_name  = azurerm_resource_group.movielens.name
  virtual_network_name = azurerm_virtual_network.hadoop_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "hadoop_nsg" {
  name                = "hadoop-nsg"
  location            = azurerm_resource_group.movielens.location
  resource_group_name = azurerm_resource_group.movielens.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Hadoop-WebUI"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8088", "9870", "8042"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Hadoop-Internal-Ports"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8020", "9000", "50070", "50075", "50090"]
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Hive-Ports"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["10000", "10002", "9083"]
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Internal"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "10.0.0.0/16"
  }
}

# Associer le NSG au subnet
resource "azurerm_subnet_network_security_group_association" "hadoop_nsg_assoc" {
  subnet_id                 = azurerm_subnet.hadoop_subnet.id
  network_security_group_id = azurerm_network_security_group.hadoop_nsg.id
}

# Public IP pour Master
resource "azurerm_public_ip" "master_public_ip" {
  name                = "master-public-ip"
  location            = azurerm_resource_group.movielens.location
  resource_group_name = azurerm_resource_group.movielens.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Public IPs pour Workers (pour débogage/accès)
resource "azurerm_public_ip" "worker_public_ip" {
  count               = 2
  name                = "worker${count.index + 1}-public-ip"
  location            = azurerm_resource_group.movielens.location
  resource_group_name = azurerm_resource_group.movielens.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface pour master
resource "azurerm_network_interface" "master_nic" {
  name                = "master-nic"
  location            = azurerm_resource_group.movielens.location
  resource_group_name = azurerm_resource_group.movielens.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.hadoop_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
    public_ip_address_id          = azurerm_public_ip.master_public_ip.id
  }
}

# Network Interface pour workers
resource "azurerm_network_interface" "worker_nic" {
  count               = 2
  name                = "worker${count.index + 1}-nic"
  location            = azurerm_resource_group.movielens.location
  resource_group_name = azurerm_resource_group.movielens.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.hadoop_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.${5 + count.index}"
    public_ip_address_id          = azurerm_public_ip.worker_public_ip[count.index].id
  }
}

# Clé SSH - Clé unique pour toutes les VM
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/hadoop_ssh_key.pem"
  file_permission = "0600"
}

# Clé publique SSH pour la configuration de l'utilisateur Hadoop
resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.module}/hadoop_ssh_key.pub"
}

# Master VM
resource "azurerm_linux_virtual_machine" "master" {
  name                = "hadoop-master"
  resource_group_name = azurerm_resource_group.movielens.name
  location            = azurerm_resource_group.movielens.location
  size                = var.master_vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.master_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  # Utilisation des provisioners pour télécharger et exécuter le script de bootstrap au lieu de templatefile manquant
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "sudo cloud-init status --wait || true",
      "sleep 30"
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = self.public_ip_address
      timeout     = "10m"
    }
  }

  # Écrire dynamiquement /tmp/hosts_entries sur le master en utilisant les IP privées réelles
  provisioner "remote-exec" {
    inline = [
      "echo 'Writing /tmp/hosts_entries with cluster private IPs'",
      "sudo bash -lc 'cat > /tmp/hosts_entries <<HOSTS\n${azurerm_network_interface.master_nic.ip_configuration[0].private_ip_address} hadoop-master\n${azurerm_network_interface.worker_nic[0].ip_configuration[0].private_ip_address} hadoop-worker1\n${azurerm_network_interface.worker_nic[1].ip_configuration[0].private_ip_address} hadoop-worker2\nHOSTS' || true",
      "sudo chmod 644 /tmp/hosts_entries || true"
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = self.public_ip_address
      timeout     = "2m"
    }
  }

  # Télécharger le script de bootstrap et l'exécuter (installera Hadoop/Hive sur le master)
  provisioner "file" {
    source      = "${path.module}/scripts/bootstrap_master.sh"
    destination = "/home/${var.admin_username}/bootstrap_master.sh"

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = self.public_ip_address
      timeout     = "5m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chown root:root /home/${var.admin_username}/bootstrap_master.sh || true",
      "sudo chmod +x /home/${var.admin_username}/bootstrap_master.sh || true",
      "sudo bash /home/${var.admin_username}/bootstrap_master.sh '${var.hadoop_password}' '${var.hadoop_version}' '${var.hive_version}' '${var.admin_username}'"
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = self.public_ip_address
      timeout     = "20m"
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts/complete_setup.sh"
    destination = "/home/${var.admin_username}/complete_setup.sh"

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = self.public_ip_address
      timeout     = "5m"
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts/diagnose_cluster.sh"
    destination = "/home/${var.admin_username}/diagnose_cluster.sh"

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = self.public_ip_address
      timeout     = "5m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.admin_username}/complete_setup.sh",
      "chmod +x /home/${var.admin_username}/diagnose_cluster.sh"
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = self.public_ip_address
      timeout     = "5m"
    }
  }

  # Propager la clé publique de l'utilisateur hadoop du master vers les workers.
  # Cela utilise un provisioner local-exec qui s'exécute sur la machine exécutant Terraform
  # et nécessite que la clé privée générée soit disponible au chemin écrit par local_file.private_key.
  provisioner "local-exec" {
    command = <<EOT
KEY="${local_file.private_key.filename}"
MASTER="${azurerm_public_ip.master_public_ip.ip_address}"
ADMIN="${var.admin_username}"
WORKERS="${join(" ", azurerm_public_ip.worker_public_ip[*].ip_address)}"

# Create a temporary script and run it with bash to avoid /bin/sh differences
TMP_SCRIPT=$(mktemp /tmp/terraform-propagate-XXXX.sh)
cat > "$TMP_SCRIPT" <<'SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
KEY="$1"
ADMIN="$2"
MASTER="$3"
WORKERS="$4"

if [ ! -f "$KEY" ]; then
  echo "WARNING: private key not found: $KEY" >&2
  exit 0
fi

# Fetch master hadoop public key (if created) to local temporary file
scp -o StrictHostKeyChecking=no -i "$KEY" "$ADMIN@$MASTER:/home/hadoop/.ssh/id_rsa.pub" /tmp/hadoop_id_rsa.pub || true

# Propagate to each worker and append into /home/hadoop/.ssh/authorized_keys
for ip in $WORKERS; do
  scp -o StrictHostKeyChecking=no -i "$KEY" /tmp/hadoop_id_rsa.pub "$ADMIN@$ip:/tmp/" || true
  ssh -o StrictHostKeyChecking=no -i "$KEY" "$ADMIN@$ip" \
    "sudo mkdir -p /home/hadoop/.ssh && sudo bash -lc 'cat /tmp/hadoop_id_rsa.pub >> /home/hadoop/.ssh/authorized_keys' && sudo chown -R hadoop:hadoop /home/hadoop/.ssh && sudo chmod 700 /home/hadoop/.ssh && sudo chmod 600 /home/hadoop/.ssh/authorized_keys && sudo rm -f /tmp/hadoop_id_rsa.pub" || true
done
rm -f /tmp/hadoop_id_rsa.pub || true
SCRIPT_EOF

chmod +x "$TMP_SCRIPT"
bash "$TMP_SCRIPT" "$KEY" "$ADMIN" "$MASTER" "$WORKERS" || true
rm -f "$TMP_SCRIPT" || true
EOT
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.hadoop_nsg_assoc
  ]
}

# Worker VMs
resource "azurerm_linux_virtual_machine" "worker" {
  count               = 2
  name                = "hadoop-worker${count.index + 1}"
  resource_group_name = azurerm_resource_group.movielens.name
  location            = azurerm_resource_group.movielens.location
  size                = var.worker_vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.worker_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  # Pas d'utilisation de templates cloud-init ; téléchargement et exécution des scripts de bootstrap existants via des provisioners
    provisioner "remote-exec" {
      inline = [
        "echo 'Waiting for cloud-init to complete...'",
        "sudo cloud-init status --wait || true",
        "sleep 30"
      ]

      connection {
        type        = "ssh"
        user        = var.admin_username
        private_key = tls_private_key.ssh_key.private_key_pem
        host        = self.public_ip_address
        timeout     = "10m"
      }
    }

    # Télécharger le script de bootstrap et l'exécuter (worker)
    provisioner "file" {
      source      = "${path.module}/scripts/bootstrap_worker.sh"
      destination = "/home/${var.admin_username}/bootstrap_worker.sh"

      connection {
        type        = "ssh"
        user        = var.admin_username
        private_key = tls_private_key.ssh_key.private_key_pem
        host        = self.public_ip_address
        timeout     = "5m"
      }
    }

  # Écrire dynamiquement /tmp/hosts_entries sur le worker en utilisant les IP privées réelles
    provisioner "remote-exec" {
      inline = [
        "echo 'Writing /tmp/hosts_entries with cluster private IPs'",
        "sudo bash -lc 'cat > /tmp/hosts_entries <<HOSTS\n${azurerm_network_interface.master_nic.ip_configuration[0].private_ip_address} hadoop-master\n${azurerm_network_interface.worker_nic[0].ip_configuration[0].private_ip_address} hadoop-worker1\n${azurerm_network_interface.worker_nic[1].ip_configuration[0].private_ip_address} hadoop-worker2\nHOSTS' || true",
        "sudo chmod 644 /tmp/hosts_entries || true"
      ]

      connection {
        type        = "ssh"
        user        = var.admin_username
        private_key = tls_private_key.ssh_key.private_key_pem
        host        = self.public_ip_address
        timeout     = "2m"
      }
    }

    provisioner "remote-exec" {
      inline = [
        "sudo chown root:root /home/${var.admin_username}/bootstrap_worker.sh || true",
        "sudo chmod +x /home/${var.admin_username}/bootstrap_worker.sh || true",
        "sudo bash /home/${var.admin_username}/bootstrap_worker.sh '${var.hadoop_password}' '${var.hadoop_version}' '${var.admin_username}'"
      ]

      connection {
        type        = "ssh"
        user        = var.admin_username
        private_key = tls_private_key.ssh_key.private_key_pem
        host        = self.public_ip_address
        timeout     = "20m"
      }
    }
  
    provisioner "file" {
      source      = "${path.module}/scripts/complete_setup.sh"
      destination = "/home/${var.admin_username}/complete_setup.sh"
  
      connection {
        type        = "ssh"
        user        = var.admin_username
        private_key = tls_private_key.ssh_key.private_key_pem
        host        = self.public_ip_address
        timeout     = "5m"
      }
    }
  
    provisioner "file" {
      source      = "${path.module}/scripts/diagnose_cluster.sh"
      destination = "/home/${var.admin_username}/diagnose_cluster.sh"
  
      connection {
        type        = "ssh"
        user        = var.admin_username
        private_key = tls_private_key.ssh_key.private_key_pem
        host        = self.public_ip_address
        timeout     = "5m"
      }
    }
  
    provisioner "remote-exec" {
      inline = [
        "chmod +x /home/${var.admin_username}/complete_setup.sh",
        "chmod +x /home/${var.admin_username}/diagnose_cluster.sh"
      ]
  
      connection {
        type        = "ssh"
        user        = var.admin_username
        private_key = tls_private_key.ssh_key.private_key_pem
        host        = self.public_ip_address
        timeout     = "5m"
      }
    }

  depends_on = [
    azurerm_subnet_network_security_group_association.hadoop_nsg_assoc,
    azurerm_linux_virtual_machine.master
  ]
}
