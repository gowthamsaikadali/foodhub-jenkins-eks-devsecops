# Latest Ubuntu 24.04 LTS AMI, published by Canonical in a public SSM parameter
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ---------- SonarQube needs its own role only for SSM shell access ----------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sonarqube" {
  name               = "${var.name}-sonarqube-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "sonarqube_ssm" {
  role       = aws_iam_role.sonarqube.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "sonarqube" {
  name = "${var.name}-sonarqube-profile"
  role = aws_iam_role.sonarqube.name
}

# ---------- Jenkins ----------
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.jenkins_instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.jenkins_sg_id]
  iam_instance_profile        = var.jenkins_instance_profile_name # AWS credentials come from the role, never from stored keys
  associate_public_ip_address = true

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only: blocks SSRF-style credential theft
    http_put_response_hop_limit = 2          # 2 so containers on the instance (Docker builds) can still reach the metadata service
  }

  root_block_device {
    volume_size = var.jenkins_volume_gb
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.tags, { Name = "${var.name}-jenkins", Role = "jenkins" })
}

# ---------- SonarQube ----------
resource "aws_instance" "sonarqube" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.sonarqube_instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.sonarqube_sg_id]
  iam_instance_profile        = aws_iam_instance_profile.sonarqube.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = var.sonarqube_volume_gb
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.tags, { Name = "${var.name}-sonarqube", Role = "sonarqube" })
}

# ---------- Elastic IPs: addresses that survive stop/start, so GitHub and SonarQube webhook URLs keep working ----------
resource "aws_eip" "jenkins" {
  domain   = "vpc"
  instance = aws_instance.jenkins.id
  tags     = merge(var.tags, { Name = "${var.name}-jenkins-eip" })
}

resource "aws_eip" "sonarqube" {
  domain   = "vpc"
  instance = aws_instance.sonarqube.id
  tags     = merge(var.tags, { Name = "${var.name}-sonarqube-eip" })
}
