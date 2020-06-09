# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE AN ECS TASK TO RUN THE DATADOG AGENT
# You can run this ECS Task on each of the servers in your ECS Cluster. For more info, see:
# https://docs.datadoghq.com/integrations/ecs/
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE DATA DOG ECS TASK
# You should run this Task directly on each EC2 Instance in your ECS Cluster
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "data_dog" {
  family                = var.data_dog_task_family_name
  container_definitions = data.template_file.container_definitions.rendered
  task_role_arn         = aws_iam_role.data_dog.arn

  volume {
    name      = "docker_sock"
    host_path = "/var/run/docker.sock"
  }

  volume {
    name      = "proc"
    host_path = "/proc/"
  }

  volume {
    name      = "cgroup"
    host_path = "/cgroup/"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE CONTAINER DEFINITIONS FOR THE DATA DOG ECS TASK
# The container definitions specify what Docker containers to run and the resources those containers need
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "container_definitions" {
  template = file("${path.module}/container-definitions/container-definitions.json")
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN IAM ROLE FOR THE ECS TASK
# You can attach IAM permissions to this role
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "data_dog" {
  name               = var.data_dog_task_family_name
  assume_role_policy = data.aws_iam_policy_document.data_dog_role.json
}

data "aws_iam_policy_document" "data_dog_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

