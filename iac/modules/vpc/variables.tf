variable "name" { type = string }
variable "cidr_block" { type = string }
variable "availability_zones" { type = list(string) }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "cluster_name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
