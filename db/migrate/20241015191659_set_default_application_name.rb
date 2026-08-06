class SetDefaultApplicationName < ActiveRecord::Migration[7.0]
  def up
    general_setting = GeneralSetting.first

    if general_setting.nil?
      GeneralSetting.create(application_name: "XBolt")
    elsif general_setting.application_name.blank?
      general_setting.update(application_name: "XBolt")
    end
  end

  def down
  end
end
