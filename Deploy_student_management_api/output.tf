output "api_url" {
  value = "http://${aws_instance.api_server.public_ip}:8080/teacher/api/v1/student/all"
}