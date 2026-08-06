class Admin::SeoSettingsController < ApplicationController
  layout 'adminpanel'
  before_action :require_full_admin
  before_action :set_seo_setting, only: [:edit, :update, :destroy]

  def index
    @seo_settings = SeoSetting.all.order(:page_name)
    @seo_setting = SeoSetting.new
  end

  def new
    @seo_setting = SeoSetting.new
  end

  def create
    @seo_setting = SeoSetting.new(seo_setting_params)
    
    if @seo_setting.save
      Activity.log(current_user, "Created SEO settings for #{@seo_setting.page_name}")
      redirect_to admin_seo_settings_path, notice: 'SEO settings created successfully!'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @seo_setting.update(seo_setting_params)
      Activity.log(current_user, "Updated SEO settings for #{@seo_setting.page_name}")
      redirect_to admin_seo_settings_path, notice: 'SEO settings updated successfully!'
    else
      render :edit
    end
  end

  def destroy
    page_name = @seo_setting.page_name
    @seo_setting.destroy
    Activity.log(current_user, "Deleted SEO settings for #{page_name}")
    redirect_to admin_seo_settings_path, notice: 'SEO settings deleted successfully!'
  end

  def initialize_defaults
    SeoSetting.initialize_defaults
    redirect_to admin_seo_settings_path, notice: 'Default SEO settings initialized successfully!'
  end

  private

  def set_seo_setting
    @seo_setting = SeoSetting.find(params[:id])
  end

  def seo_setting_params
    params.require(:seo_setting).permit(
      :page_name, :title, :description, :keywords, :author, :robots,
      :og_type, :og_url, :og_title, :og_description, :og_image,
      :twitter_card, :twitter_url, :twitter_title, :twitter_description, :twitter_image,
      :favicon_url, :apple_touch_icon_url, :canonical_url, :structured_data
    )
  end
end
