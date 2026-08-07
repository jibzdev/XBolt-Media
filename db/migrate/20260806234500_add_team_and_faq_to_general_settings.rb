class AddTeamAndFaqToGeneralSettings < ActiveRecord::Migration[7.0]
  DEFAULT_TEAM = <<~TEXT.freeze
    Jibraeel|Founder|Leads product, client delivery, and the systems behind every XBolt launch.|J
    Design|Brand & UI|Crafts clean interfaces and brand systems that feel premium on every device.|D
    Engineering|Platform|Builds fast, scalable web infrastructure for multi-tenant client sites.|E
  TEXT

  DEFAULT_FAQ = <<~TEXT.freeze
    How long does a typical website project take?|Most builds launch in 1–4 weeks depending on scope. We keep the process tight: plan, design, build, then ship.
    Do you only build websites?|We specialise in premium websites and the systems around them — hosting, analytics, lead capture, and ongoing improvements.
    Can you take over or redesign an existing site?|Yes. We can redesign, rebuild, or modernise what you already have so it loads faster and converts better.
    Do you offer ongoing support after launch?|Absolutely. We can handle updates, content changes, performance monitoring, and new features as your business grows.
    How do we get started?|Send a message through the contact page with your goals and timeline. We'll reply with next steps and a clear plan.
    Where can I learn more about XBolt Media?|Visit our LinkedIn page for company updates, or explore Work and Reviews on this site to see recent launches.
  TEXT

  def up
    unless column_exists?(:general_settings, :team_members_data)
      add_column :general_settings, :team_members_data, :text, null: false, default: DEFAULT_TEAM
    end

    unless column_exists?(:general_settings, :faq_items_data)
      add_column :general_settings, :faq_items_data, :text, null: false, default: DEFAULT_FAQ
    end
  end

  def down
    remove_column :general_settings, :faq_items_data if column_exists?(:general_settings, :faq_items_data)
    remove_column :general_settings, :team_members_data if column_exists?(:general_settings, :team_members_data)
  end
end
