## What is the default User Data of this module?

By default, this module executes the [user-data.sh](user-data.sh) that assumes the instance has EC2 Baseline installed. Check the
[ami-example.json](../../../examples/for-learning-and-testing/services/asg-service/ami-example.json) to see how to use `gruntwork-installer`
that calls [install.sh](install.sh) on the module.

If you don't want to use EC2 baseline, you can override the `default` key on the variable `cloud_init_parts`.

```hcl
cloud_init_parts = {
   default = {
     filename     = "override-init"
     content_type = "text/x-shellscript"
     content      = ""
   }
 }
```