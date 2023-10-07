resource "aws_s3_bucket" "thanos_store" {
  bucket = "thanos-indico-storage" # Replace with your desired bucket name
  acl    = "private" # Access control list (other options: public-read, public-read-write, etc.)

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_policy" "thanos_store_policy" {
  bucket = aws_s3_bucket.thanos_store.id
  policy = <<EOF
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "Statement1",
			"Effect": "Allow",
			"Principal": {
				"AWS": "arn:aws:iam::450320913695:user/thanos-indico-user"
			},
			"Action": "s3:*",
			"Resource": "arn:aws:s3:::thanos-indico-storage"
		}
	]
}
EOF
}
