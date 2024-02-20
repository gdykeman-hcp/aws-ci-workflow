output "vm_names" {
    value = { for k,v in aws_instance.nodes : k => v.public_dns }
}