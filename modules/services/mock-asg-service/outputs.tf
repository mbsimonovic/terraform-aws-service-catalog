output "service_url" {
  value = "http://${random_pet.example.id}"
}

output "instance_ip" {
  value = aws_instance.example.public_ip
}