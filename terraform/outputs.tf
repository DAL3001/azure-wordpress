output "ssh_pub_key" {
  value = file("${path.module}/../ssh/id_rsa.pub")
}