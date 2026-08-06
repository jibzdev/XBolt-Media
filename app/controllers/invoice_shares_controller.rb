class InvoiceSharesController < ApplicationController
  VIEW_RATE_LIMIT = 60
  PDF_RATE_LIMIT = 30
  RATE_WINDOW = 1.minute

  skip_before_action :require_login, raise: false
  skip_before_action :check_maintenance_mode
  before_action :set_invoice
  before_action :throttle_share_view, only: [:show]
  before_action :throttle_pdf_download, only: [:download_pdf]

  def show
    @general_setting = general_setting
  end

  def download_pdf
    send_data(
      InvoicePdfRenderer.new(invoice: @invoice, general_setting: general_setting, view_context: view_context).render,
      filename: "#{@invoice.invoice_number}.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
    )
  end

  private

  def set_invoice
    @invoice = Invoice.includes(:business).find_by!(share_token: params[:token])
  end

  def throttle_share_view
    throttle!("invoice_share:view", VIEW_RATE_LIMIT)
  end

  def throttle_pdf_download
    throttle!("invoice_share:pdf", PDF_RATE_LIMIT)
  end

  def throttle!(scope, max_attempts)
    key = "#{scope}:ip:#{RequestIp.client_ip(request)}"
    count = Rails.cache.read(key).to_i + 1
    Rails.cache.write(key, count, expires_in: RATE_WINDOW)
    return if count <= max_attempts

    render plain: "Too many requests. Please try again shortly.", status: :too_many_requests
  end
end

