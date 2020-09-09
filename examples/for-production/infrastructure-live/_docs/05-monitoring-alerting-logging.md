#  Monitoring, Alerting and Logging

Now that you've [seen how to configure a CI / CD pipeline to automatically build, test, and 
deploy](04-configure-ci-cd.md) your code, you'll want to to see what's happening in your AWS account:

* [Metrics](#metrics)
* [Alerts](#alerts)
* [Logs](#logs)




## Metrics

You can find all the metrics for your AWS account on the [CloudWatch Metrics 
Page](https://console.aws.amazon.com/cloudwatch/home?#metricsV2:). 

* Most AWS services emit metrics by default, which you'll find under the "AWS Namespaces" (e.g. EC2, ECS, RDS). 

* Custom metrics show up under "Custom Namespaces." In particular, the [cloudwatch-memory-disk-metrics-scripts 
  module](https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/metrics/) is installed on every 
  server to emit metrics not available from AWS by default, including memory and disk usage. You'll find these under
  the "Linux System" Namespace.

You may want to create a [Dashboard](https://console.aws.amazon.com/cloudwatch/home?#dashboards:)
with the most useful metrics for your services and have that open on a big screen at all times.




## Alerts

A number of alerts have been configured using the [alarms modules in 
terraform-aws-monitoring](https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/alarms) to notify you 
in case of problems, such as a service running out of disk space or a load balancer seeing too many 5xx errors. 

* You can find all the alerts in the [CloudWatch Alarms 
  Page](https://console.aws.amazon.com/cloudwatch/home?#alarm:alarmFilter=ANY). 

* You can also find [Route 53 Health Checks on this page](https://console.aws.amazon.com/route53/healthchecks/home#/). 
  These health checks test your public endpoints from all over the globe and notify you if your services are unreachable.

That said, you probably don't want to wait for someone to check that page before realizing something is wrong, so 
instead, you should subscribe to alerts via email or text message as follows:

1. Go to the [SNS Topics Page](https://console.aws.amazon.com/sns/v2/home?#/topics), select the
   `cloudwatch-alarms` topic, and click "Actions -> Subscribe to topic." 

1. Go to the [us-east-1 SNS Topics Page](https://console.aws.amazon.com/sns/v2/home?#/topics), 
   select the `route53-cloudwatch-alarms` topic, and click "Actions -> Subscribe to topic." The alarms for Route 53 
   health checks only go to `us-east-1`, so we have to have a separate SNS topic for them.
   
If you'd like alarm notifications to go to a Slack channel, check out the [sns-to-slack
module](https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/alarms/sns-to-slack).




## Logs

All of your services have been configured using the [cloudwatch-log-aggregation-scripts 
module](https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/logs/cloudwatch-log-aggregation-scripts) 
and the [eks-cloudwatch-container-logs module](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-cloudwatch-container-logs)
to send their logs to [CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/home?#logs:). Instead of SSHing to 
each server to see a log file, and worrying about losing those log files if the server fails, you can just go to the 
[CloudWatch Logs Page](https://console.aws.amazon.com/cloudwatch/home?#logs:) and browse and search log events for all 
your servers in near-real-time.




## Next steps

Next up, you'll learn how to [undeploy parts or all of the Reference Architecture](06-undeploy.md).
