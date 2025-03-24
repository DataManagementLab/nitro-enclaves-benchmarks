# EC2 Provisioning scripts

This page contains a short guide to setup the AWS specific tools and configurations in order to create and manage EC2 Instances and access S3 resources on AWS. We used the AWS SSO feature for authentication, towards which this guide is taylord. If you want or need to use another authentication method, some steps and provided utilities might not be compatible without manual adjustments.

## Getting started

1) Install aws cli2:
   linux:

   ```bash
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

   macos:

   ```bash
   curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
   sudo installer -pkg AWSCLIV2.pkg -target /
   ```

1) Create an `awsenv` file in this directory (`{projectRoot}/aws/awsenv`). It is excluded from git and stores all private AWS specific configuration used by the [`awsrc`](./awsrc) and some other places throughout this project. The variables should be insertet line by line in the format `KEY="value"` and will be exported as environment variables via `source awsrc`. You don't need to fill them out now as they will be explained in the following steps along their respective AWS configurations. However as an overview, they will include:
   - your SSH key name (`AWS_SSH_KEY_NAME`)
   - your AWS SSO profile (`AWS_PROFILE`, `S3_PROFILE`)
   - the AWS subnet ID(s) of your private AWS cloud network(s) (`AWS_SUBNET_DEFAULT`, `AWS_SUBNET_ALL`)

1) Configure AWS cli: `aws configure sso`
   - As SSO start URL use <https://d-[your-project-id].awsapps.com/start/#>
   - As SSO region use [your-sso-region]
   - Confirm in web browser
   - choose your CLI default client region where you want to deploy your EC2 instances and store your results
   - choose your CLI profile name, e.g. nitro (preferrably something short and easy to remember, since you will need this in several other places)
   - set your `AWS_PROFILE` for use in the [`awsrc`](./awsrc) and `S3_PROFILE` for downloading the results in the microbenchmarks in your [`awsenv`](./awsenv) file
     ```shell
     AWS_PROFILE=[your-sso-profile]
     S3_PROFILE=$AWS_PROFILE
     ```
   - Other options can be set as you want.
1) Setup python venv with dependencies:
   Run the `setup_venv.sh` script or use manual steps:

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip3 install -r requirements.txt
   ```

1) Setup VPC (a default VPC should be created automatically in each region). The IDs should be stored to the [`awsenv`](./awsenv) file and can be looked up in the AWS console in the browser or via `ec2laz`. Those settings specify where instances, created via the shell functions from [`awsrc`](./awsrc) will be started.
   ```
   AWS_SUBNET_DEFAULT=[default-subnet]
   AWS_SUBNET_ALL="subnet-id-1 subnet-id-2 ..."
   ```
1) Set AWS SSH Key pair in the EC2 console under `Network & Security > Key Pairs`. Importing existing key pairs is possible under Actions. Save the key name as `AWS_SSH_KEY_NAME` in your [`awsenv`](./awsenv) file.
1) Allow SSH access from the internet to instances you create:
   1) Go to Security Groups in the EC2 console: <https://[your-client-region].console.aws.amazon.com/ec2/home?region=[your-client-region]#SecurityGroups:>
   2) Select the existing default security group
   3) Go to `Inbound Rules > Edit inbound rules`
   4) Create a rule that allows SSH access from your IP/from the Internet
   5) Save
1) Create an S3 access role that can be attached to EC2 instances:
   1) Go to IAM/Roles <https://[your-client-region].console.aws.amazon.com/iam/home#/roles>
   2) Create role > AWS Service > EC2 > Next > tick AmazonS3FullAccess > Next > name the role "EC2-S3-access-role" > Create Role
1) Create an S3 Bucket for benchmarking, e.g. `nitro-enclaves-result-bucket`
1) For some useful settings, aliases, and functions (re)load `awsrc` in your shell with `source awsrc`.
1) Try if ec2 instance creation works with: `ec2c c6i.2xlarge`
1) Set up SSH key forwarding to easily clone this git repository onto the created machines. For example, add the following to your `.ssh/config`:

    ```bash
    Host *.compute.amazonaws.com
        User ec2-user
        IdentityFile [YOUR_SSH_KEY_PATH]
        IdentitiesOnly yes
        PreferredAuthentications publickey
        ForwardAgent yes
    ```

1) Get the instance public DNS name with `ec2li`.
1) Clone repository and install requirements on the new instance with `ec2setup INSTANCE_DNS`. substitute INSTANCE_DNS with the result of the previous step.
