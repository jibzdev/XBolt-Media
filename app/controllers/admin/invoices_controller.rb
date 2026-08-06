class Admin::InvoicesController < ApplicationController
  layout 'adminpanel'
  before_action :require_full_admin
  before_action :set_invoice, only: [:show, :edit, :update, :destroy, :download_pdf, :regenerate_share_token]

  def index
    @general_setting = GeneralSetting.first_or_initialize
    @invoices = Invoice.includes(:business).recent.page(params[:page]).per(20)
  end

  def new
    @general_setting = GeneralSetting.first_or_initialize
    @invoice = Invoice.new(
      issue_date: Date.current,
      due_date: 14.days.from_now.to_date,
      status: 'draft',
      line_items: [
        { 'description' => 'Website cost', 'quantity' => 1, 'unit_price' => 0, 'billing_type' => 'one_time' },
        { 'description' => 'Maintenance fee', 'quantity' => 1, 'unit_price' => 0, 'billing_type' => 'monthly' }
      ]
    )
  end

  def create
    @general_setting = GeneralSetting.first_or_initialize
    @invoice = Invoice.new(invoice_params)
    @invoice.created_by = current_user

    if @invoice.save
      log_activity("Created invoice #{@invoice.invoice_number} for #{@invoice.business.name}")
      redirect_to admin_invoice_path(@invoice), notice: 'Invoice created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @general_setting = GeneralSetting.first_or_initialize
  end

  def edit
    @general_setting = GeneralSetting.first_or_initialize
  end

  def update
    @general_setting = GeneralSetting.first_or_initialize
    if @invoice.update(invoice_params)
      log_activity("Updated invoice #{@invoice.invoice_number}")
      redirect_to admin_invoice_path(@invoice), notice: 'Invoice updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    number = @invoice.invoice_number
    @invoice.destroy!
    log_activity("Deleted invoice #{number}")
    redirect_to admin_invoices_path, notice: 'Invoice deleted successfully.'
  rescue StandardError => e
    redirect_to admin_invoice_path(@invoice), alert: "Could not delete invoice: #{e.message}"
  end

  def download_pdf
    send_data(
      InvoicePdfRenderer.new(invoice: @invoice, general_setting: GeneralSetting.first_or_initialize, view_context: view_context).render,
      filename: "#{@invoice.invoice_number}.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
    )
  end

  def regenerate_share_token
    @invoice.update!(share_token: SecureRandom.hex(16))
    redirect_to admin_invoice_path(@invoice), notice: 'Share link regenerated.'
  end

  private

  def set_invoice
    @invoice = Invoice.includes(:business).find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(
      :business_id,
      :status,
      :issue_date,
      :due_date,
      :notes,
      line_items: [:description, :quantity, :unit_price, :billing_type]
    )
  end
end
