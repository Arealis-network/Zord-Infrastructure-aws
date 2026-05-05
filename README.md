# Zord Infrastructure AWS

This repository provisions the AWS infrastructure for the EKS environment and boots an admin EC2 instance with Jenkins and SonarQube using Docker.

## Terraform

Run Terraform from the `EKS-terraform` folder.

```bash
cd EKS-terraform

terraform init \
  -backend-config="bucket=<your-tf-state-bucket>" \
  -backend-config="key=eks/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="encrypt=true"

terraform plan
terraform apply
```

If you only want to recreate the admin EC2 instance and rerun `tool.sh`, use:

```bash
terraform apply -replace=aws_instance.eks
```

To destroy all infrastructure managed by Terraform:

```bash
terraform destroy
```

## Get EC2 Public IP

After `terraform apply`, get the EC2 public IP:

```bash
aws ec2 describe-instances --region ap-south-1 \
  --query "Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]" \
  --output table
```

You can also get it from Terraform output:

```bash
terraform output ec2_public_ip
```

## Access Jenkins

Open Jenkins in your browser:

```text
http://<EC2-PUBLIC-IP>:7777
```

Jenkins runs in Docker with this port mapping:

```text
7777 -> 8080
```

## Access SonarQube

Open SonarQube in your browser:

```text
http://<EC2-PUBLIC-IP>:7771
```

SonarQube runs in Docker with this port mapping:

```text
7771 -> 9000
```

## SSH Into EC2

Connect to the admin EC2 instance:

```bash
ssh -i <your-key.pem> ec2-user@<EC2-PUBLIC-IP>
```

## Jenkins Initial Admin Password

To read the Jenkins initial admin password from EC2:

```bash
cat /home/ec2-user/jenkins-initial-admin-password
```

If that file is not present, read it directly from the Jenkins container:

```bash
sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## Useful Checks On EC2

Check running containers:

```bash
sudo docker ps
```

Check Jenkins logs:

```bash
sudo docker logs jenkins --tail 50
```

Check SonarQube logs:

```bash
sudo docker logs sonarqube --tail 50
```

Check bootstrap logs:

```bash
sudo cat /var/log/tool-bootstrap.log
```

Check Jenkins locally on the instance:

```bash
curl http://localhost:7777
```

Check SonarQube locally on the instance:

```bash
curl http://localhost:7771
```

## Notes

- Jenkins is started by `EKS-terraform/tool.sh`.
- SonarQube is started by `EKS-terraform/tool.sh`.
- If `tool.sh` changes, Terraform is configured to replace the admin EC2 instance and rerun bootstrap.
