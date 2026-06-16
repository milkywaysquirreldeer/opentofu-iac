
data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "wp-instance-role" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  name = "wp-instance-role"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore-policy-attach" {
  role       = aws_iam_role.wp-instance-role.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}
