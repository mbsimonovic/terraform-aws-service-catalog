module "ecs_deploy_runner" {
  source = "git::git@github.com:gruntwork-io/module-ci.git//modules/ecs-deploy-runner?ref=master"

  name = var.name

  container_images = var.container_images

  vpc_id              = var.vpc_id
  vpc_subnet_ids      = var.private_subnet_ids
  repository          = var.repository
  approved_apply_refs = var.approved_apply_refs
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM POLICY WITH PERMISSIONS TO INVOKE THE ECS DEPLOY RUNNER ATTACH TO IAM ENTITIES
# ---------------------------------------------------------------------------------------------------------------------

module "invoke_policy" {
  source = "git::git@github.com:gruntwork-io/module-ci.git//modules/ecs-deploy-runner-invoke-iam-policy?ref=master"

  name                                      = "invoke-${var.name}"
  deploy_runner_invoker_lambda_function_arn = module.ecs_deploy_runner.invoker_function_arn
  deploy_runner_ecs_cluster_arn             = module.ecs_deploy_runner.ecs_cluster_arn
  deploy_runner_cloudwatch_log_group_name   = module.ecs_deploy_runner.cloudwatch_log_group_name
}

resource "aws_iam_role_policy_attachment" "attach_invoke_to_roles" {
  for_each   = length(var.iam_roles) > 0 ? { for k in var.iam_roles : k => k } : {}
  role       = each.key
  policy_arn = module.invoke_policy.arn
}

resource "aws_iam_user_policy_attachment" "attach_invoke_to_users" {
  for_each   = length(var.iam_users) > 0 ? { for k in var.iam_users : k => k } : {}
  user       = each.key
  policy_arn = module.invoke_policy.arn
}

resource "aws_iam_group_policy_attachment" "attach_invoke_to_groups" {
  for_each   = length(var.iam_groups) > 0 ? { for k in var.iam_groups : k => k } : {}
  group      = each.key
  policy_arn = module.invoke_policy.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH FULL ACCESS PERMISSIONS TO REQUESTED SERVICES TO ECS TASK
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "full_access_to_services" {
  count  = length(var.permitted_services) > 0 ? 1 : 0
  name   = "full-access-to-services"
  role   = module.ecs_deploy_runner.ecs_task_iam_role_name
  policy = data.aws_iam_policy_document.full_access_to_services.json
}

data "aws_iam_policy_document" "full_access_to_services" {
  statement {
    actions   = formatlist("%s:*", var.permitted_services)
    resources = ["*"]
    effect    = "Allow"
  }
}
