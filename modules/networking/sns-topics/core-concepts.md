# Simple Notification Service (SNS) Topics

This Terraform Module creates Topics for Amazon's [Simple Notification Service (SNS)](https://aws.amazon.com/sns/). The
resources managed by these templates are:

* An SNS topic, which can be used for messages such as CloudWatch alarm notifications. You can subscribe to this topic
  in the [SNS Console](https://console.aws.amazon.com/sns/v2/home?region=us-east-1#/topics) to be notified of alarms by
  email or text message.

## About SNS Topics

#### How do SNS Topics work?

Many AWS services generate various events (e.g., an EC2 Instance was launched, an ElastiCache cluster issued a
fail-over) and often operators want to be notified of these events. How can we accomplish that?

One option would be for AWS to allow you to configure which emails get notified for each of the different events, but
this would quickly become unmanageable since an email address would be duplicated across multiple services and it'd be
hard to, for example, add a single person.

A better option is to create a "group", add one or more emails to that group, and then tell the events to notify the
group. This way, we can add/remove individuals with ease without having to reconfigure multiple services. This latter
option is how SNS Topics work. The SNS Topic is the "group", services "publish a message" to the SNS Topic, and
individual operators can register their email as a "subscriber". In fact, you could even register an HTTP endpoint as
a subscriber.

#### How do I get notified when a message is published to an SNS Topic?

The easiest way to get an email or text message for new SNS messages is to use the [SNS
Console](https://console.aws.amazon.com/sns/v2/home#/topics). Click on **SNS**, **Topics** (left side of the screen),
select a Topic, and select **Subscribe to a Topic**. Then select **Email** or **Text Message**.
