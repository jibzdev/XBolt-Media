require 'digest'
require 'net/http'
require 'tempfile'
require 'uri'

class InvoicePdfRenderer
  MAX_REMOTE_LOGO_BYTES = 1_000_000
  REMOTE_LOGO_CACHE_TTL = 30.minutes

  def initialize(invoice:, general_setting:, view_context:)
    @invoice = invoice
    @general_setting = general_setting
    @view_context = view_context
  end

  def render
    pdf = Prawn::Document.new(page_size: 'A4', margin: 36)

    add_header(pdf)
    add_meta(pdf)
    add_items_table(pdf)
    add_notes(pdf)
    add_total(pdf)

    pdf.render
  end

  private

  def add_header(pdf)
    logo_path = resolve_logo_path
    if logo_path.present?
      pdf.image logo_path, fit: [130, 50]
    else
      pdf.fill_color primary_color
      pdf.font_size(20) { pdf.text app_name, style: :bold }
      pdf.fill_color '000000'
    end
    pdf.move_down 2
    pdf.fill_color(text_muted_color)
    pdf.font_size(10) { pdf.text 'XBolt Media' }
    pdf.fill_color '000000'

    pdf.move_down 10
    pdf.fill_color primary_color
    pdf.font_size(24) { pdf.text 'INVOICE', style: :bold, align: :right }
    pdf.fill_color '000000'
    pdf.stroke_color(border_color)
    pdf.stroke_horizontal_rule
    pdf.move_down 14
  ensure
    logo_path&.close! if logo_path.is_a?(Tempfile)
  end

  def add_meta(pdf)
    left = [
      ['Invoice #', @invoice.invoice_number],
      ['Business', @invoice.business.name],
      ['Status', @invoice.status.to_s.titleize]
    ]
    right = [
      ['Issue date', @invoice.issue_date.to_s],
      ['Due date', @invoice.due_date.to_s],
      ['Generated', Time.current.to_date.to_s]
    ]

    data = left.zip(right).map do |l, r|
      [
        "<b>#{l[0]}:</b> #{l[1]}",
        "<b>#{r[0]}:</b> #{r[1]}"
      ]
    end

    pdf.table(data, cell_style: { borders: [], inline_format: true, padding: [2, 0, 2, 0] }) do
      columns(0).width = 250
      columns(1).width = 250
    end

    pdf.move_down 16
  end

  def add_items_table(pdf)
    header_bg = primary_color
    header_text = on_primary_color
    table_border = border_color

    grouped = @invoice.grouped_line_items
    [['One-time payments', 'one_time'], ['Monthly payments', 'monthly']].each do |title, key|
      items = grouped[key] || []
      next if items.blank?

      pdf.fill_color(text_muted_color)
      pdf.font_size(11) { pdf.text title, style: :bold }
      pdf.fill_color('000000')
      pdf.move_down 6

      rows = [['Item', 'Qty', 'Unit price', 'Line total']]
      items.each do |item|
        qty = item['quantity'].to_f
        unit_price = item['unit_price'].to_f
        rows << [
          item['description'].to_s,
          format('%.2f', qty),
          currency(unit_price),
          currency(qty * unit_price)
        ]
      end

      pdf.table(rows, header: true, width: 520) do
        row(0).background_color = header_bg
        row(0).text_color = header_text
        row(0).font_style = :bold
        cells.border_color = table_border
        cells.padding = [8, 10, 8, 10]
        columns(0).width = 280
        columns(1..3).align = :right
      end

      section_total = items.sum { |item| item['quantity'].to_f * item['unit_price'].to_f }
      pdf.move_down 4
      pdf.font_size(10) do
        pdf.text "Section subtotal: #{currency(section_total)}", align: :right, style: :bold
      end
      pdf.move_down 12
    end
  end

  def add_notes(pdf)
    return if @invoice.notes.blank?

    pdf.fill_color(text_muted_color)
    pdf.font_size(11) { pdf.text 'Notes', style: :bold }
    pdf.fill_color('000000')
    pdf.font_size(10) { pdf.text @invoice.notes.to_s }
    pdf.move_down 12
  end

  def add_total(pdf)
    totals_border = border_color
    totals_alt_bg = surface_alt_color.presence || 'fafafa'

    pdf.table(
      [
        ['Subtotal', currency(@invoice.subtotal)],
        ['Total', currency(@invoice.total)]
      ],
      width: 220,
      position: :right,
      cell_style: { borders: [:top, :bottom], border_color: totals_border, padding: [7, 10, 7, 10] }
    ) do
      columns(0).font_style = :bold
      columns(1).align = :right
      row(1).background_color = totals_alt_bg
    end
  end

  def resolve_logo_path
    source = @view_context.brand_logo_url.to_s.strip
    return nil if source.blank?

    if source.start_with?('http://', 'https://')
      bytes = cached_remote_logo_bytes(source)
      return nil if bytes.blank?

      file = Tempfile.new(['invoice-logo', File.extname(source)])
      file.binmode
      file.write(bytes)
      file.rewind
      return file
    end

    relative = source.delete_prefix('/')
    [
      Rails.root.join('public', relative),
      Rails.root.join('app', 'assets', 'images', relative.sub(%r{\Aassets/images/}, ''))
    ].find { |path| File.exist?(path) }
  rescue StandardError
    nil
  end

  def cached_remote_logo_bytes(url)
    key = "invoice:logo:#{Digest::SHA256.hexdigest(url)}"
    Rails.cache.fetch(key, expires_in: REMOTE_LOGO_CACHE_TTL) do
      download_remote_logo_bytes(url)
    end
  rescue StandardError
    nil
  end

  def download_remote_logo_bytes(url, redirects_left = 2)
    uri = URI.parse(url)
    return nil unless %w[http https].include?(uri.scheme)
    return nil if blocked_host?(uri.host.to_s)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 1.5
    http.read_timeout = 2.0

    request = Net::HTTP::Get.new(uri.request_uri)
    request['User-Agent'] = 'XBolt-InvoiceRenderer/1.0'
    response = http.request(request)

    if response.is_a?(Net::HTTPRedirection) && redirects_left.positive?
      location = response['location'].to_s
      return nil if location.blank?
      return download_remote_logo_bytes(location, redirects_left - 1)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)
    return nil unless response['content-type'].to_s.start_with?('image/')

    body = response.body.to_s
    return nil if body.bytesize.zero?
    return nil if body.bytesize > MAX_REMOTE_LOGO_BYTES

    body
  rescue StandardError
    nil
  end

  def blocked_host?(host)
    h = host.to_s.downcase
    return true if h.blank?
    return true if %w[localhost 127.0.0.1 ::1].include?(h)
    return true if h.end_with?('.local')
    return true if h.start_with?('10.') || h.start_with?('192.168.')
    return true if h.match?(/\A172\.(1[6-9]|2\d|3[0-1])\./)

    false
  end

  def app_name
    @general_setting.application_name.presence || 'XBolt'
  end

  def currency(number)
    @view_context.number_to_currency(number, unit: '£')
  end

  def primary_color
    sanitize_hex(@general_setting.theme_primary, '18181b')
  end

  def on_primary_color
    sanitize_hex(@general_setting.theme_on_primary, 'ffffff')
  end

  def border_color
    sanitize_hex(@general_setting.theme_border, 'e4e4e7')
  end

  def surface_alt_color
    sanitize_hex(@general_setting.theme_surface_alt, 'fafafa')
  end

  def text_muted_color
    sanitize_hex(@general_setting.theme_text_muted, '52525b')
  end

  def sanitize_hex(value, fallback)
    hex = value.to_s.delete('#')
    return fallback unless /\A[\h]{6}\z/.match?(hex)

    hex
  end
end
