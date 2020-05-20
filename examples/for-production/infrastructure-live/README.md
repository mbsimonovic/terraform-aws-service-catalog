# Live Infrastructure

This repository contains the code to deploy and manage infrastructure across all of your live environments (e.g., dev,
stage, prod) in AWS. It is built on top of the Gruntwork 
[Service Catalog](https://gruntwork.io/infrastructure-as-code-library/) and 
[Reference Architecture](https://gruntwork.io/reference-architecture/). 

![Reference Architecture](_docs/_images/ref-arch-full.png?raw=true)




## Usage instructions

* [Overview](_docs/01-overview.md): Learn about the Reference Architecture, managing infrastructure as code (IaC), and 
  how the code in this repo is organized.

* [Authenticate](_docs/02-authenticate.md): Authenticate to AWS via the web, CLI, VPN, and SSH so you can make changes 
  to the infrastructure.

* [Make changes to the infrastructure](https://github.com/gruntwork-io/aws-service-catalog/blob/master/core-concepts.md#make-changes-to-your-infrastructure): 
  Update the code and roll out changes to the infrastructure that's already deployed.

* [Deploy new infrastructure](https://github.com/gruntwork-io/aws-service-catalog/blob/master/core-concepts.md#deploy-new-infrastructure): 
  Deploy new infrastructure from the Gruntwork Service Catalog.

* [Create your own infrastructure](https://github.com/gruntwork-io/aws-service-catalog/blob/master/core-concepts.md#create-your-own-service-catalog): 
  Create your own service catalog and use it to deploy new infrastructure.

* [Deploy your apps](_docs/03-deploy-apps.md): Deploy your applications and web services (e.g., Docker images, AMIs) on 
  top of this infrastructure.

* [Configure CI / CD](_docs/04-configure-ci-cd.md): Learn about the CI / CD pipeline, including the build process, 
  automated tests, and automated deployment.  
  
* [Check the logs, metrics, and alerts](_docs/05-monitoring-alerting-logging.md): Learn about monitoring, alerting, and 
  log aggregation.  

* [Undeploy](_docs/06-undeploy.md): Undeploy infrastructure or even the entire Reference Architecture.




## Support

If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers 
[Commercial Support](https://gruntwork.io/support/) via Slack, email, and phone/video. You can contact us using one of
the following channels:

* [Gruntwork Community Slack](https://gruntwork-community.slack.com): Chat with other Gruntwork customers and the 
  Gruntwork team.

* **Private Shared Slack Channel**: For Gruntwork Pro Support and Enterprise Support customers, we create a private, 
  shared channel in Slack between your company and Gruntwork that shows up in your existing Slack workspace. Contact
  one of your Slack admins to get the channel name!  

* [support@gruntwork.io](mailto:support@gruntwork.io): If you're having trouble contact us via Slack, please feel free
  to email Gruntwork Support at any time! 
