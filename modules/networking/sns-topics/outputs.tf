output "topic_arn" {
  description = "The ARN of the SNS topic."
  value       = module.sns_topic.topic_arn
}
