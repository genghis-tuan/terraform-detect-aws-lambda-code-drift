# Detecting lambda code drift with Terraform when the deployed code is modified via AWS console

When deploying a lambda to AWS using an archive, 
such as a zip file, Terraform creates a new zip file and generates the hash of the file each time 
`terraform plan` or `terraform apply` is run.

Prior to Terraform AWS Provider version 6.27.0, when `terraform apply` is run AND applied, 
Terraform writes the hash to the `terraform.tfstate` file. 
Subsequent executions of `terraform plan` or `terraform apply` recreate the zip file and compare its hash
to the hash stored in `terraform.tfstate`.

Terraform only detected differences between the hash of the local zip file and the hash in the `terraform.tfstate` file.

If changes were manually made to the code in the deployed lambda, Terraform did not detect it because it was only 
comparing the zip file's hash to the hash in the static `terraform.tfstate` file.

**This is bad** because if someone intentionally or accidentally alters the deployed lambda code, it may never be detected.

## Testing Terraform's trigger/detection of changes to deployed lambda
In the `lambda` directory is a dummy `lambda.py` that prints a silly message.
The `main.tf` creates a `lambda_function.zip` which the 2 `aws_lambda_function` resources will use
to create 2 different lambdas. One of the lambdas uses the `code_sha256` argument. 
The other uses the `source_code_hash` argument.

Execute the following steps to see that only the lambda using `code_sha256` will detect changes made in the deployed
lambda that are out-of-sync with the source (the code in the local lambda.py).

1. Deploy the lambdas. 
```
terraform init
terraform apply
yes
```
2. Log into the AWS console and add a comment or make some change 
to the code of both `lambda.py` file of the **DEPLOYED** lambdas. For example, add the comment `# Foo`.
3. Click the `Deploy` button or `Shift+Cmd+U` to deploy the code.
4. Run `terraform apply` to see which lambda detects the code change.
5. Actually apply the Terraform by typing `yes`.
6. Refresh the browser and check the `lambda.py` of each lambda. 
**NOTE** that only the `code_sha256_trigger-test` lambda matches the source code in the local `lambda.py`.
The `source_code_hash-trigger-test` lambda will still have the changes you made manually.

## Reason
In the AWS provider version 6.27.0, the `code_sha256` was moved from being just an `Attribute Reference` to an `Argument Reference`.
This means it can be used as input to the `aws_lambda_function` instead of being a readonly output.
The `code_sha246` reads the actual sha256 hash of the code in the deployed lambda function using an AWS API. 
Terraform then compares that value with the sha256 hash of the `lambda_function.zip` and determines if a redeployment is needed.

The `source_code_hash` is a value stored in the `terraform.tfstate` file when the Terraform was last applied.
It is only read from the latest version of the static `terraform.tfstate` file.
If the local `lambda.py` has not been modified since the last time Terraform was applied (regardless of changes to the deployed `lambda.py`),
Terraform will not detect any changes.
**This is bad** because if someone intentionally or accidentally alters the deployed lambda code, `source_code_hash` may never detect it.

## Take-away
Beginning with version 6.27.0 of the Terraform AWS provider, use the `code-sha256` instead of the `source_code_hash` argument 
if changes to the deployed lambda code should trigger an update.

## Clean-up
Remove the 2 lambdas and the IAM role that were created by running:
```
terraform destroy
yes
```

## Ref

- [aws_lambda_function documentation](https://registry.terraform.io/providers/hashicorp/aws/6.27.0/docs/resources/lambda_function)
- [Install Terraform](https://formulae.brew.sh/formula/tenv)
- [AWS Console Lambda us-east-1](https://us-east-1.console.aws.amazon.com/lambda/home?region=us-east-1#/begin)