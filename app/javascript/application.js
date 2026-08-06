// Import Action Cable using ES module syntax
import { createConsumer } from "@rails/actioncable";
// Import Turbo for proper form handling
import "@hotwired/turbo-rails";
import "admin_panel";
import "tenant_site_builder";
import "confirm_modal";

// Define the global App object
window.App = {}
window.App.cable = createConsumer("/cable");
