class DemoWebsiteController < ApplicationController
  layout false

  def show
    @demo = DemoWebsiteSetting.first_or_create!
    selected_theme = params[:preview_theme].presence || @demo.theme_name
    selected_layout = params[:preview_layout].presence || @demo.layout_name
    @theme = DemoWebsiteSetting::THEMES.fetch(selected_theme, @demo.theme)
    @layout_template = DemoWebsiteSetting::LAYOUTS.key?(selected_layout) ? selected_layout : @demo.layout_template

    render "demo_website/#{@layout_template}"
  end
end
