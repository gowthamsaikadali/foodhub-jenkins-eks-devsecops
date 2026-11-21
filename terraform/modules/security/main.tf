# ===================== Jenkins server =====================
resource "aws_security_group" "jenkins" {
  name        = "${var.name}-jenkins-sg"
  description = "Jenkins server: web UI only from admin IPs and GitHub webhooks"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-jenkins-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_admin" {
  for_each          = toset(var.admin_cidrs)
  security_group_id = aws_security_group.jenkins.id
  description       = "Jenkins UI from admin"
  cidr_ipv4         = each.value
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_github" {
  for_each          = toset(var.github_webhook_cidrs)
  security_group_id = aws_security_group.jenkins.id
  description       = "GitHub webhooks"
  cidr_ipv4         = each.value
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "jenkins_all" {
  security_group_id = aws_security_group.jenkins.id
  description       = "Outbound to anywhere (package downloads, GitHub, AWS APIs)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ===================== SonarQube server =====================
resource "aws_security_group" "sonarqube" {
  name        = "${var.name}-sonarqube-sg"
  description = "SonarQube: UI from admin IPs, analysis traffic from Jenkins"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-sonarqube-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "sonar_admin" {
  for_each          = toset(var.admin_cidrs)
  security_group_id = aws_security_group.sonarqube.id
  description       = "SonarQube UI from admin"
  cidr_ipv4         = each.value
  from_port         = 9000
  to_port           = 9000
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "sonar_from_jenkins" {
  security_group_id            = aws_security_group.sonarqube.id
  description                  = "Scanner and quality-gate calls from Jenkins"
  referenced_security_group_id = aws_security_group.jenkins.id
  from_port                    = 9000
  to_port                      = 9000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "sonar_all" {
  security_group_id = aws_security_group.sonarqube.id
  description       = "Outbound (plugins, updates). The webhook back to Jenkins goes over this."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# SonarQube must call Jenkins back (quality-gate webhook), so Jenkins accepts 8080 from the SonarQube SG
resource "aws_vpc_security_group_ingress_rule" "jenkins_from_sonar" {
  security_group_id            = aws_security_group.jenkins.id
  description                  = "SonarQube webhook"
  referenced_security_group_id = aws_security_group.sonarqube.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

# ===================== Jenkins -> EKS API =====================
resource "aws_vpc_security_group_ingress_rule" "eks_api_from_jenkins" {
  security_group_id            = var.eks_cluster_security_group_id
  description                  = "Jenkins calls the EKS private API endpoint"
  referenced_security_group_id = aws_security_group.jenkins.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# ===================== RDS =====================
resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "MySQL: reachable only from EKS worker nodes"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-rds-sg" })
}

# Security-group-to-security-group rule: no IP addresses, just "whoever carries the EKS SG may connect on 3306".
resource "aws_vpc_security_group_ingress_rule" "rds_from_eks" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from EKS worker nodes"
  referenced_security_group_id = var.eks_cluster_security_group_id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
# No egress rule is added: the database never starts outbound connections.
