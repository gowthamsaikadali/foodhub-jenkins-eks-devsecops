output "jenkins_sg_id" { value = aws_security_group.jenkins.id }
output "sonarqube_sg_id" { value = aws_security_group.sonarqube.id }
output "rds_sg_id" { value = aws_security_group.rds.id }
