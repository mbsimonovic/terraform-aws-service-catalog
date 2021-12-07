# Appendix

This page contains a list of additional details that are helpful for understanding how the Reference Architecture is
organized.

## Terragrunt patterns used in the Reference Architecture

The following documents the various patterns that are used in the Reference Architecture.

### Remote state configuration

Terragrunt supports managing the [backend state
configuration](https://www.terraform.io/docs/language/settings/backends/index.html) of Terraform in a single place. This
configuration is defined using the [remote_state
block](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#remote_state), and is defined once
in the root `terragrunt.hcl` configuration. This configuration is then replicated across all the components by
leveraging the [include](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#include) feature
of Terragrunt.

Additionally, when using the S3 backend, the `remote_state` block will also automatically manage the S3 bucket for
storing the state files. Terragrunt will automatically create the S3 state bucket and DynamoDB lock table resources
whenever it detects a `remote_state` block for the S3 backend, and when those resources do not exist already. You can
read more about this behavior
[here](https://terragrunt.gruntwork.io/docs/features/keep-your-remote-state-configuration-dry/#create-remote-state-and-locking-resources-automatically).

Note that within the S3 bucket, the state file key is defined by the folder structure in this repo. That is, the state
file for the live configuration at `dev/us-west-2/dev/networking/vpc` will be stored in the same folder path
within the bucket.


### State files

Each leaf folder containing a `terragrunt.hcl` configuration is considered a Live Terragrunt Configuration for a single
component. All the resources related to deploying that component are consolidated in a single Terraform state file. The
Live Terragrunt Configuration corresponds to a single Terraform module that is called and deployed.

Each state file is tracked independently of the others. That is, if you run `apply` or `destroy` in a single folder, the
operation will only be scoped to just that component. For example, if you had the following folder structure:

```
.
└── dev
    ├── vpc
    └── eks-cluster
```

Running `apply` or `destroy` in the `eks-cluster` folder will only affect the EKS cluster and will not touch the VPC.

If you want to learn more about why it is important to break up your state files in this way, refer to [our blog post on
the topic](https://blog.gruntwork.io/how-to-manage-terraform-state-28f5697e68fa).


### Dependencies

As mentioned in the [State files](#state-files) section above, each folder represents a single component, and each
component is managed in its own state. In this setup, you can't use Terraform to link the dependencies across components
using `depends_on` or explicit references (e.g., `module.vpc.vpc_id`), as Terraform only works within a single state
file. Instead, you have to use Terragrunt
[dependency](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#dependency) blocks to link the
dependencies together.

Similar to `depends_on` in Terraform, `dependency` blocks allow you to link two Live Terragrunt Configurations together
so that Terragrunt will `apply` or `destroy` the modules in the right order when using the [run-all
command](https://terragrunt.gruntwork.io/docs/features/execute-terraform-commands-on-multiple-modules-at-once/).
Additionally, Terragrunt will automatically look up the outputs of the module referenced in the `dependency` block and
make it available to use in your configuration.

For example, consider the following folder structure:

```
.
└── dev
    ├── vpc
    └── eks-cluster
```

You can reference the ID of the VPC that gets created in the `vpc` live configuration in the `eks-cluster` live
configuration with the following setup:

```hcl
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
}
```

The `dependency.vpc.outputs` reference contains all the outputs exported by the VPC module, and is looked up at run time
using the `terraform output` command.

You can read more about how `dependency` works
[here](https://terragrunt.gruntwork.io/docs/features/execute-terraform-commands-on-multiple-modules-at-once/#passing-outputs-between-modules).


### Multiple Includes

The Reference Architecture takes advantage of the [multiple includes
feature](https://terragrunt.gruntwork.io/docs/features/keep-your-terragrunt-architecture-dry/) of Terragrunt. Each live
configuration is distributed in the following way:

- **Root `terragrunt.hcl`**: Contains configurations that are common to all accounts and environments, such as the
  remote state and provider configuration.
- **One or more envcommon configuration**: Contains configurations that are common to the component across environments.
  Typically, this configuration will also contain all the `dependency` definitions. These configurations are all stored
  in the `_envcommon` folder.

Each live configuration for the components will merge these configurations together to get the final setup using
`include` blocks. For example, the app VPC configuration has the following `include` blocks:

```hcl
include "root" {
  path = find_in_parent_folders()
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/networking/vpc-app.hcl"
}
```

This imports and merges in the configuration defined in the root `terragrunt.hcl` file, and the envcommon file located
at `_envcommon/networking/vpc-app.hcl` relative to the root `terragrunt.hcl` config.

#### Expose

Some of the configurations rely on exposed `include` blocks. This feature is enabled when the `expose = true` attribute
is set on the `include` block. Exposed `include` blocks allow the child configuration to reference values that are
defined in the parent configuration. These values are available with the reference `include.LABEL`.

For example:

_parent configuration_
```hcl
locals = {
  aws_region = "us-east-1"
}

```

_child configuration_
```hcl
include "parent" {
  path   = "/path/to/parent/configuration"
  expose = true
}

inputs = {
  region = include.parent.locals.aws_region  # Resolves to `us-east-1`
}
```

Note that the availability of values is subject to the [configuration parsing
order](https://terragrunt.gruntwork.io/docs/getting-started/configuration/#configuration-parsing-order) of Terragrunt.
This means that you won't be able to reference later stage values in early stage blocks, like accessing parent `inputs`
in `locals`.

You can work around some of this limitation by packing values in `inputs`. Terragrunt passes inputs to Terraform in a
way that Terraform ignores input values that do not correspond to an existing variable in the module. For example, if
you want to expose a reference variable that uses `dependency` blocks, you can create a private input value in the
parent configuration that references the `dependency`, and access it using exposed `include`:

_parent configuration_
```hcl
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  # This input variable is not defined in the underlying Terraform module. We use _ to decrease the likelihood of
  # accidentally using a defined variable here.
  _vpc_id = dependency.vpc.outputs.vpc_id
}

```

_child configuration_
```hcl
include "parent" {
  path   = "/path/to/parent/configuration"
  expose = true
}

inputs = {
  network_configuration = {
    vpc_id = include.parent.inputs._vpc_id
  }
}
```


#### Deep merge

Some of the configurations rely on deep merge for the included configuration files. An included configuration can be
deep merged into the current configuration when the `merge_strategy` attribute is set to `"deep"`. During a `deep`
merge, the following happens:

- For simple types (e.g., `string` and `number`), the child overrides the parent.
- For lists, the two attribute lists are combined together in concatenation.
- For maps, the two maps are combined together recursively. That is, if the map keys overlap, then a deep merge is
  performed on the map value.
- For blocks, if the label is the same, the two blocks are combined together recursively. Otherwise, the blocks are
  appended like a list. This is similar to maps, with block labels treated as keys.

This allows you to define common settings for a complex input variable in the envcommon configuration, and have the
child only inject or override a subset of the attributes.

For example:

_parent configuration_
```hcl
inputs = {
  attribute     = "hello"
  old_attribute = "old val"
  list_attr     = ["hello"]
  map_attr = {
    foo = "bar"
  }
}
```

_child configuration_
```hcl
include "parent" {
  path           = "/path/to/parent/configuration"
  merge_strategy = "deep"
}

inputs = {
  attribute     = "mock"
  new_attribute = "new val"
  list_attr     = ["mock"]
  map_attr = {
    bar = "baz"
  }
}
```

_merged configuration_
```hcl
inputs = {
  attribute     = "mock"
  old_attribute = "old val"
  new_attribute = "new val"
  list_attr     = ["hello", "mock"]
  map_attr = {
    foo = "bar"
    bar = "baz"
  }
}
```


## Common data files

There are multiple common data files in the Reference Architecture, and here's how they're pulled in:

- `common.hcl`: Project level global configuration variables that are available to all modules.
- `multi_region_common.hcl`: Project level global configuration variables that manage the multi-region modules. This
  file indicates which regions should be active across the project.
- `accounts.json`: Lookup table for metadata pertaining to an account. Unlike the `<ACCOUNT>/account.hcl` file, this is
  in JSON format so that it can be used in various CI/CD bash scripts. The top level object is a mapping from the
  account name to an object that contains the following keys:
    - `id`: The AWS ID of the account.
    - `root_user_email`: The Email address of the root user. Required if using CIS modules.
    - `deploy_order`: An integer indicating the ordering in which the accounts are deployed for component changes. Lower numbers are deployed first. Refer to the following documents for additional information:
        - [Configure Gruntwork Pipelines: CI / CD pipeline for infrastructure code](./04-configure-gw-pipelines.md#ci-cd-pipeline-for-infrastructure-code)
        - [Adding a new acccount: Set the deploy order](./06-adding-a-new-account.md#set-the-deploy-order)

- `<ACCOUNT>/account.hcl`: Account level configuration variables. This is used for each child terragrunt configuration
  to self-introspect which account the resources are being deployed to.
- `<ACCOUNT>/<REGION>/region.hcl`: Region level configuration variables. This is used for each child terragrunt
  configuration to self-introspect which region the resources are being deployed to.
