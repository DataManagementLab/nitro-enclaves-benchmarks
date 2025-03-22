# EC2 Provisioning scripts

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

2) Configure AWS cli: `aws configure sso`
   - As SSO start URL use <https://d-[your-project-id].awsapps.com/start/#>
   - As SSO region use [your-sso-region]
   - Confirm in web browser
   - choose your CLI default client region where you want to deploy your EC2 instances and store your results
   - choose your CLI profile name, e.g. nitro (preferrably something short and easy to remember, since you will need this in several other places)
   - set your `AWS_PROFILE` for use in the [`awsrc`](./awsrc)
     ```bash
     export AWS_PROFILE=[your-sso-profile]
     ```
   - Other options can be set as you want.
3) Setup python venv with dependencies:
   Run the `setup_venv.sh` script or use manual steps:

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip3 install -r requirements.txt
   ```

4) Setup VPC (a default VPC should be created automatically in each region)
5) Set AWS SSH Key pair in the EC2 console under `Network & Security > Key Pairs`. Importing existing key pairs is possible under Actions. Save the key name in the environment variable `AWS_SSH_KEY_NAME` in your local shell. This is required for the shell functions and aliases in `awsrc`
6) Allow SSH access from the internet to instances you create:
   1) Go to Security Groups in the EC2 console: <https://[your-client-region].console.aws.amazon.com/ec2/home?region=[your-client-region]#SecurityGroups:>
   2) Select the existing default security group
   3) Go to `Inbound Rules > Edit inbound rules`
   4) Create a rule that allows SSH access from your IP/from the Internet
   5) Save
7) Create an S3 access role that can be attached to EC2 instances:
   1) Go to IAM/Roles <https://[your-client-region].console.aws.amazon.com/iam/home#/roles>
   2) Create role > AWS Service > EC2 > Next > tick AmazonS3FullAccess > Next > name the role "EC2-S3-access-role" > Create Role
8) Create an S3 Bucket for benchmarking
9) For some useful settings, aliases, and functions. Load `awsrc` in your shell with `source awsrc`.
10) Try if ec2 instance creation works with: `ec2c c6i.2xlarge`
11) Set up SSH key forwarding to easily clone this git repository onto the created machines. For example, add the following to your `.ssh/config`:

    ```bash
    Host *.compute.amazonaws.com
        User ec2-user
        IdentityFile [YOUR_SSH_KEY_PATH]
        IdentitiesOnly yes
        PreferredAuthentications publickey
        ForwardAgent yes
    ```

12) Get the instance public DNS name with `ec2li`.
13) Clone repository and install requirements on the new instance with `ec2setup INSTANCE_DNS` substitute INSTANCE_DNS with the result of the previous step.
