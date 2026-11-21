output "jenkins_instance_id" { value = aws_instance.jenkins.id }
output "jenkins_public_ip" { value = aws_eip.jenkins.public_ip }
output "jenkins_private_ip" { value = aws_instance.jenkins.private_ip }
output "sonarqube_instance_id" { value = aws_instance.sonarqube.id }
output "sonarqube_public_ip" { value = aws_eip.sonarqube.public_ip }
output "sonarqube_private_ip" { value = aws_instance.sonarqube.private_ip }
