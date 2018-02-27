<powershell>
 ############################
 # Configuration parameters #
 ############################

 # Required environment variables
 $env:CHEF_SERVER_NAME = "opsworks" # Name of your Chef Server
 $env:CHEF_SERVER_ENDPOINT = "opsworks-c6zlxgopzmeufhf2.eu-central-1.opsworks-cm.io" # FQDN of your Chef Server
 $env:REGION = "eu-central-1" # Region of Chef Server (us-east-1, us-west-1 or eu-west-1)
 $env:CHEF_NODE_NAME = "$(Invoke-WebRequest http://169.254.169.254/latest/meta-data/instance-id)" # Use EC2 Instance ID as Chef Node Name

 # Optional environment variables
 $env:CHEF_ORGANIZATION = "default" # AWS OpsWorks for Chef Server always creates the organization "default"
 $env:CHEF_NODE_ENVIRONMENT = "" # E.g. development, staging, onebox...
 $env:CHEF_CLIENT_VERSION = "13.6.4" # Latest, if left empty

 # Recommended: Upload the chef-client cookbook from the Chef Supermarket  https://supermarket.chef.io/cookbooks/chef-client
 # Use this to apply sensible default settings for your chef-client config like logrotate and running as a service
 # You can add more cookbooks in the run list, based on your needs
 # Compliance runs require recipe[audit] to be added to the runlist.
 $env:CHEF_RUN_LIST="recipe[chef-client]" # E.g. "recipe[chef-client],recipe[apache2],recipe[audit]"

 # Chef installation parameters
 $env:CHEF_FOLDER = "C:\chef"
 $env:CHEF_CA_PATH = "c:\chef\opsworks-cm-ca-2016-root.pem"
 $env:CLIENT_KEY = "$env:CHEF_FOLDER\client.pem"



 ##########################################
 # Do not modify anything below this line #
 ##########################################

 # Download file, sleep and retry x times on error
 function download_with_retries {
     $stop_try = $false
     $retry_count = 1
     $uri = $args[0]
     $outfile = $args[1]
     $name_of_dl = $args[2]
     $max_retries = 5
     $retry_sleep = 10
     do {
         try {
             Invoke-WebRequest -Uri "$uri" -OutFile $outfile
             Write-Host "Successfully downloaded the $name_of_dl"
             $stop_try = $true
         }
         catch {
             if ($retry_count -gt $max_retries) {
                 Write-Host "Tried $max_retries times, all failed! Check your connectivity"
                 $stop_try = $true
                 exit 1
             } else {
                 Write-Host "Failed to download $name_of_dl - retrying after $retry_sleep seconds..."
                 Start-Sleep -Seconds $retry_sleep
                 $retry_count = $retry_count + 1
             }
         }
     }
     while ($stop_try -eq $false)
 }

 # Download and silently install AWS CLI
 function install_aws_cli {
     Write-Host "Installing AWS CLI..."
     download_with_retries "https://s3.amazonaws.com/aws-cli/AWSCLI64.msi" "awscli.msi" "AWS CLI Installation"
     Start-Process msiexec -ArgumentList "/qn /i awscli.msi" -wait
 }

 # Execute AWS CLI opsworks-cm command
 function aws_cli {
     aws opsworks-cm --region $env:REGION --output text $args --server-name $env:CHEF_SERVER_NAME
 }

 # Chef client installation.
 # https://docs.chef.io/install_omnibus.html
 function install_chef_client {
     Write-Host "Installing Chef-Client..."
     . { Invoke-WebRequest -UseBasicParsing https://omnitruck.chef.io/install.ps1 } | Invoke-Expression; install -version "$env:CHEF_CLIENT_VERSION"
     # Update Path environment variable to include new Chef folder
     $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
 }

 # Write ASCII-encoded client.rb Chef configuration file
 function write_chef_config {
     $config_contents = @"
 chef_server_url   'https://$env:CHEF_SERVER_ENDPOINT/organizations/$env:CHEF_ORGANIZATION'
 node_name         '$env:CHEF_NODE_NAME'
 ssl_ca_file       '$env:CHEF_CA_PATH'
"@
 $config_contents | Set-Content "C:\chef\client.rb" -Encoding ASCII
 }

 # Install trusted certificates
 function install_trusted_certs {
     download_with_retries "https://opsworks-cm-$env:REGION-prod-default-assets.s3.amazonaws.com/misc/opsworks-cm-ca-2016-root.pem" "$env:CHEF_CA_PATH" "private key"
 }

 # Associate new Chef node with Chef Server
 function associate_node {
     # Modifiy permissions of Chef folder to allow full Admin access
     $acl = Get-Acl $env:CHEF_FOLDER
     $permission = "Administrator","FullControl","Allow"
     $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
     $acl.SetAccessRule($accessRule)
     $acl | Set-Acl $env:CHEF_FOLDER

     # Generate OpenSSL RSA certificate
     $openssl = "C:\opscode\chef\embedded\bin\openssl.exe"
     & $openssl genrsa -out "$env:CLIENT_KEY" 2048 2>&1 | Out-Null
     $public_key = & $openssl rsa -in "$env:CLIENT_KEY" -pubout

     # Associate node with Chef Server
     aws_cli associate-node --node-name $env:CHEF_NODE_NAME --engine-attributes """Name=CHEF_ORGANIZATION,Value=$env:CHEF_ORGANIZATION""" """Name=CHEF_NODE_PUBLIC_KEY,Value='$($($public_key)-join "`n")'"""
 }

 # Wait for node association
 function wait_node_associated {
     $status_token = $args[0]
     aws_cli wait node-associated --node-association-status-token $status_token
 }

 Start-Transcript -Path c:\Windows\Temp\associate-node-$(get-date -uFormat "%m%d%Y%H%MS").log
 # Execution
 install_aws_cli
 install_chef_client
 write_chef_config
 $node_association_status_token = associate_node
 install_trusted_certs
 wait_node_associated $node_association_status_token

 # Run chef-client
 if ("$env:CHEF_NODE_ENVIRONMENT") {
     chef-client -r "$env:CHEF_RUN_LIST" -e "$env:CHEF_NODE_ENVIRONMENT"
 } else {
     chef-client -r "$env:CHEF_RUN_LIST"
 }

Stop-Transcript
</powershell>
