## How do I update my instance?

1. Rebuild your instance using https://www.packer.io[Packer].

    From the `modules/services/ec2-instance` directory:

    ```bash
    packer build \
        -var aws_region="<AWS REGION YOU WANT TO USE>" \
        -var service_catalog_ref="<SERVICE CATALOG VERSION YOU WANT TO USE>" \
        -var version_tag="<VERSION TAG FOR AMI>" \
        ec2-instance.json
    ```

2. Plan your change via terraform

```bash
terraform plan -var ami_version_tag=<VERSION TAG FOR AMI> -out current.plan
```

3. Apply the change

```bash
terraform apply current.plan
```
## How do I use User Data?

User Data can be defined to run scripts on boot of your instance.

1. Create a script that you want to run on boot.

    ```bash
    $ cat <<EOF >user-data.sh
    > #!/bin/bash
    >
    > echo "The current date is: \$(date)" > /tmp/date.txt
    > EOF
    ```

1. In your terraform file, create a `template_file` data section:

    ```
    data "template_file" "user_data" {
      template = file("${path.module}/user-data.sh")
    }
    ```

1. Add a `cloud_init` local variable with the rendered contents of the file:

    ```
    locals {
      cloud_init = {
        "sample-file" = {
            filename     = "sample-file"
            content_type = "text/x-shellscript"
            content      = data.template_file.user_data.rendered
        }
      }
    }
    ```

1. In the module instantiation of `ec2_service`, set `cloud_init_parts` to the local variable:

    ```
    module "ec2_instance" {
    ...
    cloud_init_parts = local.cloud_init
    ```

When the instance boots, you will be able to find your script in `/var/lib/cloud/instances/INSTANCE_ID/scripts/sample-file`, and it will be run.

You can see a complete example in the [`examples/for-learning-and-testing/services/ec2-instance`](/examples/for-learning-and-testing/services/ec2-instance) directory.
## How do I create and mount an EBS volume?

1. Define the `ebs_volumes` variable. It is a map of volume names to an object with the `aws_ebs_volume` resource parameters.

  ```
  ebs_volumes = {
    "demo-volume" = {
      type        = "gp2"
      size        = 5
      device_name = "/dev/xvdf"
      mount_point = "/mnt/demo"
      region      = "us-east-1"
      owner       = "ubuntu"
    },
    "demo-volume2" = {
      type        = "gp2"
      size        = 10
      device_name = "/dev/xvdg"
      mount_point = "/mnt/demo2"
      region      = "us-east-1"
      owner       = "ubuntu"
    },
  }
  ```

  Additional keys include "encrypted", "iops", "snapshot_id", "kms_key_id", "throughput", and "tags". See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume for more information. 
