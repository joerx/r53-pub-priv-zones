# Route 53 public/private DNS Resolution Demo

- Terraform plan
- Creates a new VPC with an associated internal hosted zone
- Starts an EC2 instance inside that VPC to test DNS resolution
- Given a `domain = "example.com"`, it creates the following DNS records:

|Name|Zone|Comment|
|----|----|-------|
|`foo.example.com`|Public|Resolves from anywhere|
|`bar.internal.example.com`|Public|Will be masked by internal zone|
|`foo.internal.example.com`|Private|Will only resolve inside the VPC|

## Usage

- Ensure you have AWS CLI configured and pointing at the right cloud
- Create `terrafrom.tfvars` as shown below
- There must be an existing hosted zone for `domain`
- SSH key must exist in your account

    ```hcl
    domain = "honestbee.com"

    key_name = "honestbee-data"
    ```

- Run `tf plan`, `tf apply`

## Test

- SSH into the instance
- Use `dig` to test name resolution (replace `example.com` with your domain):

    ```sh
    $ dig +short foo.example.com
    1.2.3.4

    $ dig +short bar.internal.example.com
    # no answer

    $ dig +short foo.internal.example.com
    10.0.0.1
    ```

- Resolve `bar.internal.example.com` locally:

    ```sh
    $ dig +short bar.internal.example.com
    1.2.3.5
    ```
