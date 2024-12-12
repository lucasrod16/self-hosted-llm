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
  ami = "ami-036841078a4b68e14"

  # https://github.com/ollama/ollama/blob/main/docs/gpu.md
  # https://docs.aws.amazon.com/dlami/latest/devguide/gpu.html
  # https://aws.amazon.com/ec2/spot/pricing/
  # https://medium.com/@bijit211987/top-nvidia-gpus-for-llm-inference-8a5316184a10
  # 
  # https://aws.amazon.com/ec2/instance-types/g6e/
  # https://www.nvidia.com/en-us/data-center/l40s/
  # G6e - NVIDIA L40S Tensor Core GPU
  # ~ $0.6354 (g6e.xlarge 1 GPU)
  instance_type = "g6e.xlarge"

  key_name          = aws_key_pair.ssh_key.key_name
  security_groups   = [aws_security_group.chatbot_sg.name]
  user_data         = file("./user_data.sh")
  availability_zone = "us-east-2a"

  instance_market_options {
    market_type = "spot"
  }

  root_block_device {
    volume_size = 500
    volume_type = "gp3"
  }
}

resource "aws_volume_attachment" "chatbot_volume_attachment" {
  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html
  # The device names that you specify for NVMe EBS volumes in a block device mapping
  # are renamed using NVMe device names (/dev/nvme[0-26]n1).
  # 
  # The block device driver can assign NVMe device names in a different order
  # than you specified for the volumes in the block device mapping.
  # 
  # https://docs.aws.amazon.com/ebs/latest/userguide/nvme-ebs-volumes.html
  # Amazon EBS volumes are exposed as NVMe block devices on Amazon EC2 instances built on the AWS Nitro System.
  # 
  # tldr; device_name is renamed using NVMe device names (/dev/nvme[0-26]n1)
  # because G6e instance types are built on the Nitro v2 system.
  # 
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-nitro-instances.html
  device_name = "/dev/sdh"
  instance_id = aws_instance.chatbot_server.id
  volume_id   = "vol-0f2153615108429a8"
}

output "instance_ip" {
  value = aws_instance.chatbot_server.public_ip
}

output "instance_id" {
  value = aws_instance.chatbot_server.id
}
