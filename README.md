# azure-wordpress
Azure wordpress

## Create a service Principal for Terraform Cloud to authenticate
`az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/b97ff2ec-e6dd-4551-8b1d-b2ac5b9f0f7a" --name="Terraform Cloud"`