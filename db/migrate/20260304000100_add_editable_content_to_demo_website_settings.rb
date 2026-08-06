class AddEditableContentToDemoWebsiteSettings < ActiveRecord::Migration[7.0]
  def change
    change_table :demo_website_settings, bulk: true do |t|
      t.string :services_title, null: false, default: "Our Services"
      t.text :services_intro, null: false, default: "Comprehensive solutions tailored for your business."
      t.string :work_title, null: false, default: "Our Work"
      t.text :work_intro, null: false, default: "Recent projects showcasing quality and attention to detail."
      t.string :testimonials_title, null: false, default: "What Our Clients Say"
      t.text :testimonials_intro, null: false, default: "Real feedback from happy clients."
      t.string :faq_title, null: false, default: "Frequently Asked Questions"
      t.text :faq_intro, null: false, default: "Answers to common questions about our services."
      t.string :contact_title, null: false, default: "Let's Work Together"
      t.text :contact_intro, null: false, default: "Ready to get started? Get in touch for a free quote."

      t.text :feature_cards_data, null: false, default: "Fast Delivery|Quick turnaround times without compromising quality.\nQuality Assured|Every project undergoes rigorous quality checks.\nBest Value|Transparent pricing and excellent value.\nConsultancy & Design|Expert planning, consultation, and support."
      t.text :project_cards_data, null: false, default: "Project One|Featured Project|Professional work showcasing quality and detail.\nProject Two|Featured Project|Professional work showcasing quality and detail.\nProject Three|Featured Project|Professional work showcasing quality and detail.\nProject Four|Featured Project|Professional work showcasing quality and detail.\nProject Five|Featured Project|Professional work showcasing quality and detail.\nProject Six|Featured Project|Professional work showcasing quality and detail."
      t.text :testimonial_cards_data, null: false, default: "John Doe|Business Owner|Absolutely outstanding work and communication.\nSarah Miller|Homeowner|The process was smooth and the result was perfect.\nMichael Johnson|Property Manager|Professional from start to finish."
      t.text :faq_items_data, null: false, default: "How long does a project take?|Most projects are completed within 2-4 weeks depending on scope.\nDo you offer free consultations?|Yes, we offer free initial consultations.\nWhat areas do you service?|We serve local and surrounding areas.\nWhat payment methods do you accept?|Bank transfer, card, and cash are supported.\nDo you provide warranties?|Yes, all work includes a warranty.\nHow do I get started?|Send us a message and we will guide you through the next steps."
      t.text :stat_items_data, null: false, default: "100%|Satisfaction\n500+|Projects\n24/7|Support\n10+|Years"
      t.text :process_steps_data, null: false, default: "Discovery|We learn your goals and requirements.\nDesign|We craft a clear visual direction.\nBuild|We deliver a polished, high-quality result.\nLaunch|We deploy and support your launch."
    end
  end
end
