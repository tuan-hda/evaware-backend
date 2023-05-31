import boto3

"""
Khởi tạo đối tượng client cho  Amazon S3 Bucket.

"""
s3_client = boto3.client(
    's3'
)
