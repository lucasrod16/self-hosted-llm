packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  formatted_timestamp = formatdate("YYYY-MM-DD", timestamp())
}

source "amazon-ebs" "ubuntu_ami" {
  region        = "us-east-2"
  instance_type = "t2.micro"
  ami_name      = "self-hosted-llm-ubuntu-2404-${local.formatted_timestamp}"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"]
    most_recent = true
  }
  ssh_username = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.ubuntu_ami"]

  provisioner "file" {
    source      = "./install-deps.sh"
    destination = "/tmp/install-deps.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /tmp/install-deps.sh",
      "/tmp/install-deps.sh"
    ]
  }
}
