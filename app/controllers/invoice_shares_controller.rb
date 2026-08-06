class InvoiceSharesController < ApplicationController
  PDF_RATE_LIMIT = 30
  PDF_RATE_WINDOW = 1.minute

  skip_before_action :require_login, raise: false
  skip_before_action :check_maintenance_mode
  before_action :set_invoice
  before_action :throttle_pdf_download, only: [:download_pdf]

  def show
    @general_setting = GeneralSetting.first_or_initialize
  end

  def download_pdf
    send_data(
      InvoicePdfRenderer.new(invoice: @invoice, general_setting: GeneralSetting.first_or_initialize, view_context: view_context).render,
      filename: "#{@invoice.invoice_number}.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
    )
  end

  private

  def set_invoice
    @invoice = Invoice.includes(:business).find_by!(share_token: params[:token])
  end

  def throttle_pdf_download
    key = "invoice_share:pdf:ip:#{request.remote_ip}"
    count = Rails.cache.read(key).to_i + 1
    Rails.cache.write(key, count, expires_in: PDF_RATE_WINDOW)
    return if count <= PDF_RATE_LIMIT

    render plain: 'Too many requests. Please try again shortly.', status: :too_many_requests
  end
end
