# Pin npm packages by running ./bin/importmap

pin "application"
pin "admin_panel"
pin "tenant_site_builder" # legacy no-op; editor uses Stimulus website-builder
pin "landing"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin "confirm_modal"
pin_all_from "app/javascript/channels", under: "channels"
