output "public_subnet_ids" {
  value = module.vpc_app.public_subnet_ids
}
output "vpc_id" {
  value = module.vpc_app.vpc_id
}

output "instance_ip" {
  value = aws_instance.example.public_ip
}
