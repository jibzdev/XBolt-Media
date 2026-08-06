class Admin::DemoWebsitesController < ApplicationController
  layout "adminpanel"
  before_action -> { require_admin_area(:demo_website) }

  def show
    @general_setting = GeneralSetting.first_or_initialize
    @demo = DemoWebsiteSetting.first_or_create!
    @themes = DemoWebsiteSetting::THEMES
    @layouts = DemoWebsiteSetting::LAYOUTS
    @businesses = Business.order(:name)
  end

  def update
    @demo = DemoWebsiteSetting.first_or_create!
    @themes = DemoWebsiteSetting::THEMES
    @layouts = DemoWebsiteSetting::LAYOUTS
    @businesses = Business.order(:name)

    if @demo.update(demo_params)
      redirect_to admin_demo_website_path, notice: "Demo website updated."
    else
      @general_setting = GeneralSetting.first_or_initialize
      render :show, status: :unprocessable_entity
    end
  end

  private

  def demo_params
    params.require(:demo_website_setting).permit(
      :site_title,
      :hero_badge,
      :hero_heading,
      :hero_subheading,
      :cta_primary_text,
      :cta_secondary_text,
      :about_title,
      :about_body,
      :services_title,
      :services_intro,
      :work_title,
      :work_intro,
      :testimonials_title,
      :testimonials_intro,
      :faq_title,
      :faq_intro,
      :contact_title,
      :contact_intro,
      :feature_cards_data,
      :project_cards_data,
      :testimonial_cards_data,
      :faq_items_data,
      :stat_items_data,
      :process_steps_data,
      :theme_name,
      :layout_name,
      :contact_email,
      :contact_phone,
      :tenant_image_business_id,
      :image_slots_data
    )
  end
end
