variable "resource_group_name" {
  description = "Nom du groupe de ressources Azure"
  type        = string
  default     = "MovieLens-projet"
}

variable "location" {
  description = "Région Azure pour les ressources"
  type        = string
  default     = "francecentral"
}

variable "master_vm_size" {
  description = "Taille de la VM master"
  type        = string
  default     = "Standard_B2as_v2"
}

variable "worker_vm_size" {
  description = "Taille des VMs workers"
  type        = string
  default     = "Standard_B2s_v2"
}

variable "admin_username" {
  description = "Nom d'utilisateur admin pour les VMs"
  type        = string
  default     = "hadoopadmin"
}

variable "hadoop_password" {
  description = "Mot de passe pour l'utilisateur hadoop (utilisé par les scripts bootstrap)"
  type        = string
  default     = "changeme"
}

variable "hadoop_version" {
  description = "Version de Hadoop à installer"
  type        = string
  default     = "3.3.6"
}

variable "hive_version" {
  description = "Version de Hive à installer (master)"
  type        = string
  default     = "3.1.3"
}
