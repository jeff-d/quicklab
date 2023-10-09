# Private Servers

A private server is a server that is not exposed to the internet. Create private servers in the QuickLab network's private subnets.

## Create & Delete Servers

- create private servers
  - use the included shell script (`create-server.sh`)
  - execute the script from the terraform project directory (e.g. `aws`)
  - specify the system type ("windows" OR "linux") using the `-s` parameter
  - (optional) specify the count of servers to create using the `-c` parameter (default: `1`)
  - servers are created using the latest Amazon Linux 2023 and Windows Server 2022 Images
  - run the script twice to create Linux and Windows servers
  - example command:
    ```
    chmod +x modules/bastion/create-server.sh && ./modules/bastion/create-server.sh -s linux
    ```
- delete private servers
  - use the included shell script (`delete-server.sh`)
  - execute the script from the terraform project directory (e.g. `aws`)
  - the script only deletes servers created by `create-servers.sh`
  - example command:
    ```
    chmod +x modules/bastion/delete-server.sh && ./modules/bastion/delete-server.sh
    ```

## Connect to Servers

The QuickLab bastion facilitates connections to private servers. Servers created using `create-server.sh` use the same KeyPair as the QuickLab bastion.

### Linux (SSH)

- note the PrivateDnsName of your server

  - example command: `PrivateDnsName=ip-10-0-10-12.us-west-2.compute.internal`

- connect to the server using the included ssh config file

  - example command: `ssh -F $(terraform output -raw bastion_proxyjump_config) $PrivateDnsName`

### Windows (RDP)

- note server's InstanceId and PrivateDnsName

  - example command: `InstanceId=i-0db3f0a9221f42922 && PrivateDnsName=ip-10-0-11-128.us-west-2.compute.internal`

- decrypt server's password

  - example command:
    ```
    aws ec2 get-password-data --instance-id $InstanceId --priv-launch-key $(terraform output -raw network_keyfile) --query {AdminPassword:PasswordData} --output text
    ```

- tunnel RDP traffic through an SSH connection to the QuickLab Bastion

  - example command: `eval $(terraform output -raw bastion_connect) -L 3389:$PrivateDnsName:3389`

- use an RDP client to initiatiate an RDP connection to `localhost` using the generated RDP connection file

  - example command: `open ~/quicklab/aws/localhost.rdp`

- log in using the server's credentials, e.g

  - username: `Administrator`
  - password: `<decrypted password>`

## Documentation

- [README](../README.md)
- [Requirements](requirements.md)
- [Usage](usage.md)
- [Working with QuickLab Components](components.md)
- [Private Servers](servers.md)
- [Sumo Logic Astronomy Shop](astroshop.md)
- [QuickLab Monitoring](monitoring.md)
- [Project Notes](notes.md)
