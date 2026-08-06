class Admin::MessagesController < ApplicationController
  layout 'adminpanel'
  before_action -> { require_admin_area(:messages) }
  before_action :set_message, only: [:show, :destroy, :mark_read]

  def index
    @general_setting = GeneralSetting.first_or_initialize
    @messages = visible_messages_scope.recent.page(params[:page]).per(20)
  end

  def show
    @general_setting = GeneralSetting.first_or_initialize
    @message.mark_as_read! if @message.read_at.nil?
  end

  def mark_read
    @message.mark_as_read!
    redirect_to admin_messages_path, notice: 'Message marked as read.'
  end

  def destroy
    @message.destroy!
    redirect_to admin_messages_path, notice: 'Message deleted.'
  rescue StandardError => e
    redirect_to admin_messages_path, alert: "Could not delete message: #{e.message}"
  end

  def prune
    window = prune_window_param
    unless window
      return redirect_to admin_messages_path, alert: 'Invalid prune window.'
    end

    cutoff = window.ago
    deleted_count = visible_messages_scope.where('created_at < ?', cutoff).delete_all
    window_label = params[:window].to_s

    redirect_to admin_messages_path, notice: "Pruned #{deleted_count} message(s) older than #{window_label}."
  end

  private

  def visible_messages_scope
    ContactMessage.where(business_id: nil).visible_to(current_user)
  end

  def set_message
    @message = visible_messages_scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_messages_path, alert: 'Message not found.'
  end

  def prune_window_param
    case params[:window].to_s
    when '24h' then 24.hours
    when '1w' then 1.week
    when '1m' then 1.month
    else nil
    end
  end
end
