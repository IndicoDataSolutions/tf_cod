#
# A TERRAFORM local_exec provisioner to remove all the content from a bucket because
# Terraform is so bloody slow doing it
#
# Arrange for this script to be executed before the bucket is deleted.
#
# ALSO you must arrange for AWS CLI credentials to available to this script
#
# ONE way to do that is to run the terraform command in the context of AWS CLI
# credentials too, setting the standard AWS CLI environment variables, plus the
# AWS_SDK_LOAD_CONFIG set to true.
#
# Note also that this is unlikely to work on a bucket with object versioning enabled
#
BUCKET_ID=${1:-$BUCKET_ID}
aws s3 rm "s3://${BUCKET_ID}/" --recursive --only-show-errors || echo "WARNING: S3 rm ${BUCKET_ID} reported errors" >&2

#
# We exit with success whether or not the CLI command ended with success.This then
# allows the normal TF clearance algorithm to to clean up as a fallback.
#
exit 0