require 'aws-sdk-s3'
require 'securerandom'

class ImageUploadService
  BUCKET_NAME = 'medappdev'
  REGION = 'auto'
  ACCESS_KEY_ID = '909f4c93bfa01fc95a7c918c7364de28'
  SECRET_ACCESS_KEY = '8b912ab7b44b248e9d135c2624eb575e1551943e4182a255db791ff89eaaa0d8'
  PUBLIC_URL_DOMAIN = 'https://pub-8fd83a2723de4458a5abcafe7bce787c.r2.dev'
  ENDPOINT = 'https://f1eed593022155f2b8a0871f3eb999dd.r2.cloudflarestorage.com'

  def self.upload(file)
    Rails.logger.debug "Starting image upload process"
    Rails.logger.debug "File details: #{file.inspect}"

    s3_client = Aws::S3::Client.new(
      region: REGION,
      access_key_id: ACCESS_KEY_ID,
      secret_access_key: SECRET_ACCESS_KEY,
      endpoint: ENDPOINT
    )
    Rails.logger.debug "S3 client initialized"

    key = SecureRandom.hex(10) + File.extname(file.original_filename)
    Rails.logger.debug "Generated key for file: #{key}"

    begin
      s3_client.put_object(bucket: BUCKET_NAME, key: key, body: file)
      Rails.logger.debug "File successfully uploaded to S3"
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error "S3 upload failed: #{e.message}"
      raise
    end

    url = "#{PUBLIC_URL_DOMAIN}/#{key}"
    Rails.logger.debug "Generated public URL: #{url}"
    url
  end

  def self.delete(key)
    Rails.logger.debug "Starting image deletion process"

    s3_client = Aws::S3::Client.new(
      region: REGION,
      access_key_id: ACCESS_KEY_ID,
      secret_access_key: SECRET_ACCESS_KEY,
      endpoint: ENDPOINT
    )
    Rails.logger.debug "S3 client initialized"

    begin
      s3_client.delete_object(bucket: BUCKET_NAME, key: key)
      Rails.logger.debug "File successfully deleted from S3"
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error "S3 deletion failed: #{e.message}"
      raise
    end
  end
end
