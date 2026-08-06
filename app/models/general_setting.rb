class GeneralSetting < ApplicationRecord
  HEX_COLOR_REGEX = /\A#(?:\h{3}|\h{6})\z/

  validates :theme_primary, :theme_primary_hover, :theme_on_primary,
            :theme_bg, :theme_surface, :theme_surface_alt, :theme_border,
            :theme_text, :theme_text_muted,
            format: { with: HEX_COLOR_REGEX, message: "must be a hex color like #111111" },
            allow_blank: true
end
