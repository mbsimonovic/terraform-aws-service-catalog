output "service_url" {
  value = "http://${random_pet.example.id}"
}

output "cloud_init" {
  value = data.template_cloudinit_config.cloud_init.rendered
}