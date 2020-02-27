# Jenkins Core Concepts


## The JENKINS_HOME directory

This modules mount the [JENKINS_HOME directory](https://wiki.jenkins-ci.org/display/JENKINS/Administering+Jenkins)
on a separate, persistent EBS volume at path `/jenkins`. Unlike a root volume on an EC2 Instance, this EBS volume will
persist between redeploys so you don't lose all your data each time you push out new code. We also run the `ec2-backup`
module to take nightly snapshots of the EBS volume, so you can restore from a snapshot if something goes wrong.


## Upgrading Jenkins

If you want to upgrade the Jenkins version, your best option is to set the `jenkins_version` variable to a new version
number and building a new AMI using the Packer template in [jenkins/packer](/modules/mgmt/jenkins/packer). If you use 
the Jenkins UI to do upgrades, you will lose that upgrade the next time you deploy a new AMI. A Jenkins upgrade 
installs a new war file for Jenkins onto the root volume. The `JENKINS_HOME` directory (which lives on a separate EBS
volume) should remain unchanged and continue working with the new version.


## Why use an ALB?

We have deployed Jenkins with an [Application Load 
Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) in front of it for a 
few reasons:

1. It provides SSL termination.
1. It can use SSL certificates from the [AWS Certificate Manager](https://aws.amazon.com/certificate-manager/). These
   certificates are free and auto-renew, which makes maintenance much easier.
1. It allows us to run Jenkins itself in a private subnet and not expose it directly to any users. Given all the 
   different types of code a developer is likely to run on Jenkins, it will be hard to lock it down fully, so 
   preventing it from being exposed to the outside world offers a little more protection from dumb mistakes (e.g. 
   opening up a port).

