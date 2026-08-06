class GeneralSetting < ApplicationRecord
  HEX_COLOR_REGEX = /\A#(?:\h{3}|\h{6})\z/
  MAX_TEAM_MEMBERS = 12
  MAX_FAQ_ITEMS = 20

  DEFAULT_TEAM_MEMBERS = [
    {
      name: "Jibraeel",
      role: "Founder",
      bio: "Leads product, client delivery, and the systems behind every XBolt launch.",
      initials: "J"
    },
    {
      name: "Design",
      role: "Brand & UI",
      bio: "Crafts clean interfaces and brand systems that feel premium on every device.",
      initials: "D"
    },
    {
      name: "Engineering",
      role: "Platform",
      bio: "Builds fast, scalable web infrastructure for multi-tenant client sites.",
      initials: "E"
    }
  ].freeze

  DEFAULT_FAQ_ITEMS = [
    {
      question: "How long does a typical website project take?",
      answer: "Most builds launch in 1–4 weeks depending on scope. We keep the process tight: plan, design, build, then ship."
    },
    {
      question: "Do you only build websites?",
      answer: "We specialise in premium websites and the systems around them — hosting, analytics, lead capture, and ongoing improvements."
    },
    {
      question: "Can you take over or redesign an existing site?",
      answer: "Yes. We can redesign, rebuild, or modernise what you already have so it loads faster and converts better."
    },
    {
      question: "Do you offer ongoing support after launch?",
      answer: "Absolutely. We can handle updates, content changes, performance monitoring, and new features as your business grows."
    },
    {
      question: "How do we get started?",
      answer: "Send a message through the contact page with your goals and timeline. We'll reply with next steps and a clear plan."
    },
    {
      question: "Where can I learn more about XBolt Media?",
      answer: "Visit our LinkedIn page for company updates, or explore Work and Reviews on this site to see recent launches."
    }
  ].freeze

  validates :theme_primary, :theme_primary_hover, :theme_on_primary,
            :theme_bg, :theme_surface, :theme_surface_alt, :theme_border,
            :theme_text, :theme_text_muted,
            format: { with: HEX_COLOR_REGEX, message: "must be a hex color like #111111" },
            allow_blank: true

  def team_members
    rows = parse_pipe_rows(
      team_members_data,
      keys: %i[name role bio initials],
      limit: MAX_TEAM_MEMBERS
    )

    rows = DEFAULT_TEAM_MEMBERS if rows.empty?
    rows.map do |row|
      name = row[:name].to_s.strip
      initials = row[:initials].presence || name.to_s[0, 1].to_s.upcase
      {
        name: name,
        role: row[:role].to_s.strip,
        bio: row[:bio].to_s.strip,
        initials: initials.to_s.strip.upcase[0, 3]
      }
    end
  end

  def faq_items
    rows = parse_pipe_rows(
      faq_items_data,
      keys: %i[question answer],
      limit: MAX_FAQ_ITEMS
    )

    rows = DEFAULT_FAQ_ITEMS if rows.empty?
    rows.map do |row|
      {
        question: row[:question].to_s.strip,
        answer: row[:answer].to_s.strip
      }
    end
  end

  def self.serialize_team_members(members)
    Array(members).map do |member|
      [
        member[:name] || member["name"],
        member[:role] || member["role"],
        member[:bio] || member["bio"],
        member[:initials] || member["initials"]
      ].map { |part| part.to_s.gsub("|", "/").strip }.join("|")
    end.join("\n")
  end

  def self.serialize_faq_items(items)
    Array(items).map do |item|
      [
        item[:question] || item["question"],
        item[:answer] || item["answer"]
      ].map { |part| part.to_s.gsub("|", "/").strip }.join("|")
    end.join("\n")
  end

  private

  def parse_pipe_rows(raw, keys:, limit:)
    raw.to_s.lines.map(&:strip).reject(&:blank?).first(limit).filter_map do |line|
      parts = line.split("|", keys.length).map { |part| part.to_s.strip }
      next if parts.all?(&:blank?)
      next if parts.first.blank?

      keys.each_with_index.with_object({}) do |(key, idx), item|
        item[key] = parts[idx].to_s
      end
    end
  end
end
