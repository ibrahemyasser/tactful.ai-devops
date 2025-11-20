output "bastion_instance_id" {
  description = "Instance ID of bastion host"
  value       = aws_instance.bastion.id
}

output "bastion_private_ip" {
  description = "Private IP of bastion host"
  value       = aws_instance.bastion.private_ip
}

output "bastion_security_group_id" {
  description = "Security group ID of bastion host"
  value       = aws_security_group.bastion.id
}

output "ssm_connect_command" {
  description = "AWS SSM command to connect to bastion"
  value       = "aws ssm start-session --target ${aws_instance.bastion.id}"
}
