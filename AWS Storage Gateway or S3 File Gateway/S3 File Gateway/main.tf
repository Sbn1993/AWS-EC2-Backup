##Terraform code to create instance with t3 medium in aws for AWS S3 file gateway using NFS file share, also adding the IAM role to allow access for s3 file gateway to s3 bucket.
provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example" {
  ami           = "ami-033d1edba5606cffb"
  instance_type = "c6a.xlarge"


  # Add 160 GB storage
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 160
  }
}


resource "aws_iam_role" "s3_file_gateway_role" {
  name = "s3_file_gateway_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "storagegateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "s3_file_gateway_policy" {
  name = "s3_file_gateway_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.file_share.arn}",
        "${aws_s3_bucket.file_share.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3_file_gateway_attachment" {
  role = aws_iam_role.s3_file_gateway_role.name
  policy_arn = aws_iam_policy.s3_file_gateway_policy.arn
}

resource "aws_s3_bucket" "file_share" {
  bucket = "my-file-share"
  acl    = "private"
}

resource "aws_storagegateway_nfs_file_share" "nfs_file_share" {
  gateway_arn = aws_storagegateway_gateway.example.arn
  share_name  = "nfs-file-share"
  file_share_arn = aws_storagegateway_s3_file_share.file_share.arn
  role_arn = aws_iam_role.s3_file_gateway_role.arn
}

resource "aws_storagegateway_s3_file_share" "file_share" {
  s3_bucket_arn = aws_s3_bucket.file_share.arn
  gateway_arn   = aws_storagegateway_gateway.example.arn
}

resource "aws_storagegateway_gateway" "example" {
  name     = "my-gateway"
  type     = "FILE_S3"
  region   = "us-east-2"

}


resource "aws_vpc_endpoint" "s3_file_gateway" {
  vpc_id                  = aws_vpc.example.id
  service_name            = "com.amazonaws.us-west-2.storagegateway"
  policy                  = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_vpc_endpoint" "s3_bucket" {
  vpc_id                  = aws_vpc.example.id
  service_name            = "com.amazonaws.us-west-2.s3"
  policy                  = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_network_interface_attachment" "example" {
  device_index         = 0
  network_interface_id = aws_network_interface.example.id
  instance_id          = aws_instance.example.id
}

resource "aws_network_interface" "example" {
  subnet_id = aws_subnet.example.id
  private_ips = ["10.0.1.10"]
  vpc_endpoint_ids = [aws_vpc_endpoint.s3_file_gateway.id, aws_vpc_endpoint.s3_bucket.id]
}

resource "aws_subnet" "example" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
}
