class Activity < ApplicationRecord
  include ActionView::Helpers::DateHelper

  belongs_to :user

  after_create_commit { broadcast_activity }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  def self.log(user, description)
    create!(
      user: user,
      description: description
    )
  end

  def formatted_time
    time_ago_in_words(created_at) + " ago"
  end

  private

  def broadcast_activity
    ActionCable.server.broadcast("activity_channel", {
      user: { username: user.username, id: user.id },
      description: description,
      created_at: formatted_time
    })
  end
end
