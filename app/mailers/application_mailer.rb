class ApplicationMailer < ActionMailer::Base
  default from: 'XBolt <rkcustomsportsmouth@gmail.com>'
  layout 'mailer'
  
  # Add headers to prevent spam filtering
  before_action :set_anti_spam_headers
  
  private
  
  def set_anti_spam_headers
    headers['X-Mailer'] = 'XBolt Email System'
    headers['X-Priority'] = '3'
    headers['X-MSMail-Priority'] = 'Normal'
    headers['Importance'] = 'Normal'
    headers['X-MimeOLE'] = 'Produced By XBolt'
    headers['List-Unsubscribe'] = '<mailto:xboltmedia@gmail.com>'
    headers['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click'
    headers['X-Auto-Response-Suppress'] = 'All'
    headers['Precedence'] = 'bulk'
    headers['X-Report-Abuse'] = 'Please report abuse to xboltmedia@gmail.com'
  end
end
