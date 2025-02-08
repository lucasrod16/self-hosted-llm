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
    key            = "self-hosted-llm/tfstate"
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

resource "aws_security_group" "llm_sg" {
  name        = "llm_security_group"
  description = "Security group to allow access to self-hosted LLM"

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
  key_name   = "llm-key-pair"
  public_key = file("~/.ssh/id_rsa.pub")
}

data "aws_ami" "latest_llm_ami" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["self-hosted-llm-ubuntu-2404-*"]
  }
}

resource "aws_instance" "llm_server" {
  ami = data.aws_ami.latest_llm_ami.id

  # https://github.com/ollama/ollama/blob/main/docs/gpu.md
  # https://docs.aws.amazon.com/dlami/latest/devguide/gpu.html

  # https://medium.com/@bijit211987/top-nvidia-gpus-for-llm-inference-8a5316184a10

  # https://aws.amazon.com/ec2/pricing/on-demand/
  # https://aws.amazon.com/ec2/spot/pricing/
  # https://aws.amazon.com/ec2/instance-types/g6e/


  # https://www.nvidia.com/en-us/data-center/l40s/
  # G6e - NVIDIA L40S Tensor Core GPU
  # g6e.12xlarge instance specs:
  #   - 4 GPUs
  #   - 192 GB VRAM
  #   - 48 vCPUs
  #   - 384 GB RAM
  #   - $10.49264 on-demand hourly rate
  instance_type = "g6e.12xlarge"

  key_name        = aws_key_pair.ssh_key.key_name
  security_groups = [aws_security_group.llm_sg.name]
  user_data       = file("./user_data.sh")

  # must be in the same AZ as the EBS volume
  availability_zone = "us-east-2a"

  root_block_device {
    volume_size = 100
  }

  # instance_market_options {
  #   market_type = "spot"
  # }
}

resource "aws_volume_attachment" "llm_volume_attachment" {
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
  # tl;dr device_name is renamed using NVMe device names (/dev/nvme[0-26]n1)
  # because G6e instance types are built on the Nitro v2 system.
  # 
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-nitro-instances.html
  device_name = "/dev/sdh"
  instance_id = aws_instance.llm_server.id
  volume_id   = "vol-0f2153615108429a8"
}

output "instance_ip" {
  value = aws_instance.llm_server.public_ip
}

output "instance_id" {
  value = aws_instance.llm_server.id
}
