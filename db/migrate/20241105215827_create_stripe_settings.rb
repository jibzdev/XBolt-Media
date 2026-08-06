class CreateStripeSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :stripe_settings do |t|
      t.string :publishable_key
      t.string :secret_key
      t.string :webhook_secret

      t.timestamps
    end
  end
end
