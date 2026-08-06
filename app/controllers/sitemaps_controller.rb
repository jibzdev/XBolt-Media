class SitemapsController < ApplicationController
  layout false

  skip_before_action :update_last_active, :check_maintenance_mode, :track_page_view, raise: false

  def show
    render xml: SitemapXmlBuilder.main(request: request)
  end

  def tenant
    business = current_business
    return head :not_found if business.nil?

    render xml: SitemapXmlBuilder.tenant(business: business, request: request)
  end
end
