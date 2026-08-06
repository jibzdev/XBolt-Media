# ActiveRecord::Encryption keeps its own config object. Setting
# Rails.application.config.active_record.encryption.* alone is not enough —
# the railtie copies credentials (often nil) into ActiveRecord::Encryption.config
# before regular initializers run. Re-configure explicitly here.
require "digest"

primary_key =
  ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence ||
  Digest::SHA256.hexdigest("ar-encryption-primary:#{Rails.application.secret_key_base}")

deterministic_key =
  ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence ||
  Digest::SHA256.hexdigest("ar-encryption-deterministic:#{Rails.application.secret_key_base}")

key_derivation_salt =
  ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence ||
  Digest::SHA256.hexdigest("ar-encryption-salt:#{Rails.application.secret_key_base}")

ActiveRecord::Encryption.configure(
  primary_key: primary_key,
  deterministic_key: deterministic_key,
  key_derivation_salt: key_derivation_salt,
  support_unencrypted_data: true
)
