require "aws-sdk-s3"
require "securerandom"

class ImageUploadService
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg
    image/png
    image/webp
    image/gif
  ].freeze

  MAX_FILE_SIZE = 5.megabytes

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ValidationError < Error; end

  def self.upload(file)
    new.upload(file)
  end

  def self.delete(key)
    new.delete(key)
  end

  def upload(file)
    validate_file!(file)

    key = "#{SecureRandom.hex(16)}#{safe_extension(file)}"
    body = file.respond_to?(:tempfile) && file.tempfile ? file.tempfile : file

    client.put_object(
      bucket: bucket_name,
      key: key,
      body: body,
      content_type: file.content_type.to_s,
      cache_control: "public, max-age=31536000, immutable"
    )

    "#{public_url_domain}/#{key}"
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error("Image upload failed: #{e.class}: #{e.message}")
    raise Error, "Upload failed"
  end

  def delete(key)
    normalized = key.to_s.strip
    raise ValidationError, "Invalid image key" if normalized.blank? || normalized.include?("..") || normalized.include?("/")

    client.delete_object(bucket: bucket_name, key: normalized)
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error("Image deletion failed: #{e.class}: #{e.message}")
    raise Error, "Deletion failed"
  end

  private

  def validate_file!(file)
    raise ValidationError, "No file provided" if file.blank?
    raise ValidationError, "Invalid upload" unless file.respond_to?(:original_filename) && file.respond_to?(:content_type)

    content_type = file.content_type.to_s.downcase
    unless ALLOWED_CONTENT_TYPES.include?(content_type)
      raise ValidationError, "Unsupported file type"
    end

    size = file_size(file)
    raise ValidationError, "Empty file" if size.nil? || size <= 0
    raise ValidationError, "File too large (max #{MAX_FILE_SIZE / 1.megabyte}MB)" if size > MAX_FILE_SIZE
  end

  def file_size(file)
    return file.size if file.respond_to?(:size) && file.size
    return file.tempfile.size if file.respond_to?(:tempfile) && file.tempfile
    nil
  end

  def safe_extension(file)
    ext = File.extname(file.original_filename.to_s).downcase
    return ext if ext.match?(/\A\.(jpe?g|png|webp|gif)\z/)

    case file.content_type.to_s.downcase
    when "image/jpeg" then ".jpg"
    when "image/png" then ".png"
    when "image/webp" then ".webp"
    when "image/gif" then ".gif"
    else ".bin"
    end
  end

  def client
    @client ||= begin
      options = {
        region: region,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key
      }

      if (ep = endpoint)
        options[:endpoint] = ep
        options[:force_path_style] = true
      end

      Aws::S3::Client.new(**options)
    end
  end

  def bucket_name
    require_any_env("R2_BUCKET", "AWS_BUCKET")
  end

  def region
    env_value("R2_REGION", "AWS_REGION") || "auto"
  end

  def access_key_id
    require_any_env("R2_ACCESS_KEY_ID", "AWS_ACCESS_KEY_ID")
  end

  def secret_access_key
    require_any_env("R2_SECRET_ACCESS_KEY", "AWS_SECRET_ACCESS_KEY")
  end

  def endpoint
    env_value("R2_ENDPOINT")
  end

  def public_url_domain
    explicit = env_value("R2_PUBLIC_URL")
    return explicit.sub(%r{/\z}, "") if explicit.present?

    "https://#{bucket_name}.s3.#{region}.amazonaws.com"
  end

  def env_value(*names)
    names.each do |name|
      value = ENV[name].to_s.strip
      return value if value.present?
    end
    nil
  end

  def require_any_env(*names)
    value = env_value(*names)
    return value if value.present?

    raise ConfigurationError, "Missing required environment variable: #{names.join(' or ')}"
  end
end
