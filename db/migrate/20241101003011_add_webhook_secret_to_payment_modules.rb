class AddWebhookSecretToPaymentModules < ActiveRecord::Migration[7.0]
  def change
    add_column :payment_modules, :webhook_secret, :string
  end
end
