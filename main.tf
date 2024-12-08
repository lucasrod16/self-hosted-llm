terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    http = {
      source = "hashicorp/http"
    }
  }
  backend "s3" {
    bucket         = "lucasrod16-tfstate"
    key            = "chatbot/tfstate"
    region         = "us-east-2"
    dynamodb_table = "lucasrod16-tfstate"
  }
}

provider "aws" {
  region = "us-east-2"
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

resource "aws_security_group" "chatbot_sg" {
  name        = "chatbot_security_group"
  description = "Security group to allow access to chatbot"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${trimspace(data.http.my_ip.response_body)}/32"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${trimspace(data.http.my_ip.response_body)}/32"]
  }

  ingress {
    from_port   = 11434
    to_port     = 11434
    protocol    = "tcp"
    cidr_blocks = ["${trimspace(data.http.my_ip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "chatbot-key-pair"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "chatbot_server" {
  ami             = "ami-036841078a4b68e14"
  instance_type   = "m5a.4xlarge"
  key_name        = aws_key_pair.ssh_key.key_name
  security_groups = [aws_security_group.chatbot_sg.name]
  user_data       = file("./user_data.sh")
}

output "instance_ip" {
  value = aws_instance.chatbot_server.public_ip
}

output "instance_id" {
  value = aws_instance.chatbot_server.id
}
