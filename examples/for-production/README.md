# Examples for production

This folder contains standalone examples of how to use the modules in the [modules folder](/modules) that are optimized 
for direct usage in production. This is code from the [Gruntwork Reference 
Architecture](https://gruntwork.io/reference-architecture/), and it shows you how we build an end-to-end, integrated
tech stack on top of the Gruntwork Service Catalog. To keep the code DRY and manage dependencies between modules, the
code is deployed using [Terragrunt](https://terragrunt.gruntwork.io/). However, all of the Service Catalog modules will 
work with pure Terraform too. To see examples of using the Service Catalog with Terraform, or to try out examples 
designed for easy learning/experimenting (but not direct usage in production), head over to the 
[examples/for-learning-and-testing folder](/examples/for-learning-and-testing) instead. 