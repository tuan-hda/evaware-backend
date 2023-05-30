import boto3

from evaware_backend.settings import AWS_S3_REGION_NAME

s3_client = boto3.client(
    's3'
)
