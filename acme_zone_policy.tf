resource "aws_iam_policy" "allow_writing_acme_zone" {
  # ... other configuration ...
  name = "allow_writing_staging_acme_zone"
  policy = "${data.aws_iam_policy_document.allow_writing_acme_zone.json}"
}


data "aws_iam_policy_document" "allow_writing_acme_zone" {

  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/${data.aws_route53_zone.acme.zone_id}"]
    effect = "Allow"
  }

  statement {
    actions   = ["route53:GetChange"]
    resources = ["*"]
    effect = "Allow"
  }

  statement {
    actions   = ["route53:ListHostedZones"]
    resources = ["*"]
    effect = "Allow"
  }

}

//
//{
//"Version": "2012-10-17",
//"Statement": [
//    {
//        "Effect": "Allow",
//        "Action": [
//            "route53:ChangeResourceRecordSets"
//        ],
//        "Resource": [
//            "arn:aws:route53:::hostedzone/{ZONEABCD}"
//        ]
//    },
//    {
//        "Effect": "Allow",
//        "Action": [
//            "route53:ListHostedZonesByName"
//        ],
//        "Resource": [
//            "*"
//        ]
//    }
//]}