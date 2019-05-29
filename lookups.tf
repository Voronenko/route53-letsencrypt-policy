data "aws_route53_zone" "acme" {
    name = "${var.domain}"
}

