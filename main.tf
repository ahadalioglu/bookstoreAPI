terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
 
    github = {
        source  = "integrations/github"
        version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "github" {
  token = "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"
}

resource "github_repository" "myrepo" {
  name = "bookstore-api"
  auto_init = true
  #default_branch = "main"
  visibility = "private"
}

resource "github_branch_default" "main" {
  branch = "main"
  repository = github_repository.myrepo.name
}

variable "files" {
  default = ["Dockerfile", "docker-compose.yml", "bookstore-api.py", "requirements.txt"]
}
resource "github_repository_file" "app-files" {
  for_each = toset(var.files)
  content = file(each.value)
  file = each.value
  branch = "main"
  commit_message = "managed by Terraform"
  overwrite_on_create = true
  repository = github_repository.myrepo.name
}

resource "aws_instance" "tf-ec2" {
  ami = "ami-05fa00d4c63e32376"
  instance_type = "t2.micro"
  key_name = "FirstKey"
  security_groups = ["tf-docker-sg-prj203"]
  tags = {
    "Name" = "BookStoreAPI-WebServer"
  }

  user_data =<<-EOF
    #!/bin/bash
    yum update -y
    yum install httpd -y
    amazon-linux-extras install docker -y
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
    curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" \
          -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    mkdir /home/ec2-user/bookstore-api
    TOKEN="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"
    FOLDER="https://$TOKEN@raw.githubusercontent.com/ahadalioglu/bookstore-api/main"
    curl -s -o "/home/ec2-user/bookstore-api/requirements.txt" -L $FOLDER"/requirements.txt"
    curl -s -o "/home/ec2-user/bookstore-api/Dockerfile" -L $FOLDER"/Dockerfile"
    curl -s -o "/home/ec2-user/bookstore-api/docker-compose.yml" -L $FOLDER"/docker-compose.yml"
    curl -s -o "/home/ec2-user/bookstore-api/bookstore-api.py" -L $FOLDER"/bookstore-api.py"
    cd /home/ec2-user/bookstore-api
    docker build -t bookstoreapi:latest .
    docker-compose up -d
  EOF
  depends_on = [github_repository.myrepo, github_repository_file.app-files]
}

resource "aws_security_group" "docker-api-sg" {
 name = "tf-docker-sg-prj203"
 tags = {
    "Name" = "Docker-EC2-SG-prj203"
 } 

 ingress {
   cidr_blocks = [ "0.0.0.0/0" ]
   from_port = 80
   protocol = "tcp"
   to_port = 80
 }

 ingress {
   cidr_blocks = [ "0.0.0.0/0" ]
   from_port = 22
   protocol = "tcp"
   to_port = 22
 }

 egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    protocol = -1
    to_port = 0
 }
}

output "website" {
  value = "http://${aws_instance.tf-ec2.public_dns}"
}