output "public_dns" {
  value = "${aws_instance.hello.public_dns}"
}

output "public_ip" {
  value = "${aws_instance.hello.public_ip}"
}
