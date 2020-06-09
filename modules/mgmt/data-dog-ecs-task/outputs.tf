output "data_dog_task_arn" {
  value = aws_ecs_task_definition.data_dog.arn
}

output "data_dog_task_family" {
  value = aws_ecs_task_definition.data_dog.family
}

output "data_dog_task_revision" {
  value = aws_ecs_task_definition.data_dog.revision
}

output "data_dog_task_iam_role_arn" {
  value = aws_iam_role.data_dog.arn
}

output "data_dog_task_iam_role_name" {
  value = aws_iam_role.data_dog.name
}

