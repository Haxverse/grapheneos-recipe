#!/bin/bash -i
#
set -o nounset
set -o pipefail
set -e

if [[ -z "$R2_BUCKET_NAME" ]]; then
   echo "Giving up on uploading, R2_BUCKET_NAME is not set."
   exit 0
fi

if [[ -z "$R2_ACCESS_KEY_ID" ]]; then
   echo "Giving up on uploading, R2_ACCESS_KEY_ID is not set."
   exit 0
fi

if [[ -z "$R2_SECRET_ACCESS_KEY" ]]; then
   echo "Giving up on uploading, R2_SECRET_ACCESS_KEY is not set."
   exit 0
fi

if [[ -z "$R2_ENDPOINT" ]]; then
   echo "Giving up on uploading, R2_ENDPOINT is not set."
   exit 0
fi

cd /ham-output

# Configure rclone for R2 if not already configured
if ! rclone listremotes | grep -q "^r2:"; then
    echo "Configuring rclone for Cloudflare R2..."
    rclone config create r2 s3 \
        provider "Cloudflare" \
        region "auto" \
        access_key_id "$R2_ACCESS_KEY_ID" \
        secret_access_key "$R2_SECRET_ACCESS_KEY" \
        endpoint "$R2_ENDPOINT"
fi

# Upload the release file without syncing
echo "Uploading release file to Cloudflare R2..."
chmod 600 /ham-files/*
rclone copy /ham-output r2:$R2_BUCKET_NAME --progress

echo "Upload complete."
