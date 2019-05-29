resource "aws_iam_user" "acme-writer" {
  name = "acme-domain-writer"
}

resource "aws_iam_user_policy_attachment" "acme-writer-policy" {
  user       = "${aws_iam_user.acme-writer.name}"
  policy_arn = "${aws_iam_policy.allow_writing_acme_zone.arn}"
}