require 'net/http'

class TenantSitesController < ApplicationController
  layout false
  TENANT_CONTACT_BURST_LIMIT_PER_HOUR = 20
  TENANT_RECAPTCHA_ACTION = 'tenant_contact'.freeze
  TENANT_RECAPTCHA_VERIFY_URL = URI('https://www.google.com/recaptcha/api/siteverify')
  # Tenant sites are static; they should never require Rails CSRF tokens.
  # Without this, any POST to a tenant host will raise InvalidAuthenticityToken
  # before we can return 405.
  skip_before_action :verify_authenticity_token

  def contact_submit
    @business = current_business
    return render_contact_response('Business not found.', status: :not_found) if @business.nil?
    return render_contact_response('Tenant email configuration is not set up yet.', status: :unprocessable_entity) unless @business.tenant_contact_configured?

    contact = tenant_contact_params

    if contact[:name].blank? || contact[:email].blank? || contact[:message].blank?
      return render_contact_response('Please fill in your name, email, and message.', status: :unprocessable_entity)
    end

    ip = request.remote_ip.to_s
    recaptcha_result = verify_tenant_recaptcha(contact[:recaptcha_token], ip: ip)
    unless recaptcha_result[:success]
      ContactMessage.track_spam_attempt_and_auto_ban!(
        ip: ip,
        reason: recaptcha_result[:reason],
        source: "tenant:#{@business.id}",
        score: 80,
        hard_block: true
      )
      Rails.logger.warn("Tenant contact reCAPTCHA blocked for business=#{@business.id}: reason=#{recaptcha_result[:reason]} score=#{recaptcha_result[:score]} ip=#{ip}")
      return render_contact_response('Please complete the spam check and try again.', status: :unprocessable_entity)
    end

    if tenant_rate_limited?(business: @business, ip: ip, email: contact[:email].to_s)
      return render_contact_response("You've already sent a message recently. Please wait 15 minutes before sending another.", status: :too_many_requests)
    end

    email = contact[:email].to_s.strip
    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      return render_contact_response('Please enter a valid email address.', status: :unprocessable_entity)
    end

    name = contact[:name].to_s.strip
    phone = contact[:phone].to_s.strip.presence
    message_text = contact[:message].to_s.strip

    assessment = ContactMessage.assess_spam(
      name: name,
      email: email,
      phone: phone,
      message: message_text,
      honeypot: contact[:website],
      user_agent: request.user_agent.to_s
    )
    if assessment[:score] >= 50
      ContactMessage.track_spam_attempt_and_auto_ban!(
        ip: ip,
        reason: assessment[:reasons].join(','),
        source: "tenant:#{@business.id}",
        score: assessment[:score],
        hard_block: assessment[:hard_block]
      )
      Rails.logger.warn("Tenant contact spam blocked for business=#{@business.id}: score=#{assessment[:score]} reasons=#{assessment[:reasons].join(',')} ip=#{ip}")
      return render_contact_response('Thanks! Your message has been received.', status: :ok)
    end

    if tenant_hourly_burst_limited?(business: @business)
      Rails.logger.warn("Tenant contact burst limit reached for business=#{@business.id}")
      return render_contact_response('Thanks! Your message has been received.', status: :ok)
    end

    ContactMailer.tenant_contact_notification(
      business: @business,
      name: name,
      email: email,
      phone: phone,
      message: message_text
    ).deliver_now

    ContactMailer.tenant_contact_confirmation(
      business: @business,
      name: name,
      email: email,
      message: message_text
    ).deliver_now

    track_tenant_event!(@business, 'contact_submit')
    mark_tenant_rate_limit!(business: @business, ip: ip, email: email)
    increment_tenant_hourly_counter!(business: @business)
    ContactMessage.reset_spam_attempt_counter!(ip)

    render_contact_response('Thanks! Your message has been sent. We will be in touch soon.')
  rescue StandardError => e
    Rails.logger.error("Tenant contact submit failed for business=#{@business&.id}: #{e.class}: #{e.message}")
    render_contact_response("Sorry — we couldn't send your message right now. Please try again later.", status: :internal_server_error)
  end

  def show
    # Tenant sites are static. Block unsafe methods on tenant hosts to avoid CSRF issues.
    unless request.get? || request.head?
      return head :method_not_allowed
    end

    @general_setting = GeneralSetting.first_or_initialize
    @business = current_business
    return render plain: 'Business not found', status: :not_found if @business.nil?

    # Static-first tenant serving:
    # If a built site exists in /public/tenant_sites/<subdomain>/..., serve files directly.
    # Otherwise, show the default "Under construction" page.
    site_root = Rails.root.join('public', 'tenant_sites', @business.subdomain.to_s)
    requested = request.path.to_s.delete_prefix('/')

    if (abs = resolve_tenant_file(site_root, requested))
      serve_tenant_file(abs)
      return
    end

    # If an asset/file is missing, don't try to render HTML for non-HTML requests.
    # This avoids ActionController::UnknownFormat for things like missing .png/.css.
    unless request.format.html?
      return head :not_found
    end

    # SPA fallback: if a deployed site exists and the request is HTML, serve index.html.
    # This supports React/Vue/etc. client-side routing (/dashboard, /pricing, ...).
    index = site_root.join('index.html')
    if File.file?(index)
      serve_tenant_file(index)
      return
    end
  end

  private

  def resolve_tenant_file(site_root, requested)
    return nil unless site_root.present?

    rel = requested.to_s
    rel = rel.sub(%r{\A/+}, '')

    candidates =
      if rel.blank?
        ['index.html']
      elsif rel.end_with?('/')
        [File.join(rel, 'index.html')]
      elsif File.extname(rel).present?
        [rel]
      else
        ["#{rel}.html", File.join(rel, 'index.html')]
      end

    candidates.each do |cand|
      next if cand.include?('..')

      abs = site_root.join(cand).cleanpath
      next unless abs.to_s.start_with?(site_root.to_s)
      next unless File.file?(abs)

      return abs
    end

    nil
  end

  def serve_tenant_file(abs)
    stat = File.stat(abs)
    ext = File.extname(abs.to_s)
    mime = Rack::Mime.mime_type(ext, 'application/octet-stream')

    # Conditional GET / caching
    fresh_when etag: [@business.id, abs.to_s, stat.mtime.to_i, stat.size], last_modified: stat.mtime, public: true
    return if performed?

    if mime.start_with?('text/html')
      response.headers['Cache-Control'] = 'public, max-age=60'
      html = File.binread(abs)
      html = inject_contact_bridge(html)
      html = inject_gallery_bridge(html)
      html = inject_event_tracking_bridge(html)
      render html: html.html_safe, content_type: mime
      return
    else
      # Tenant builds should fingerprint assets; cache aggressively.
      response.headers['Cache-Control'] = 'public, max-age=31536000, immutable'
    end

    send_file abs, type: mime, disposition: 'inline'
  end

  def tenant_contact_params
    raw = if params[:contact].is_a?(ActionController::Parameters)
      params.require(:contact).permit(:name, :email, :phone, :message, :website, :recaptcha_token, :'g-recaptcha-response').to_h
    elsif params[:tenant_site].is_a?(ActionController::Parameters)
      params.require(:tenant_site).permit(:name, :email, :phone, :message, :website, :recaptcha_token, :'g-recaptcha-response').to_h
    else
      params.permit(:name, :email, :phone, :message, :website, :recaptcha_token, :'g-recaptcha-response').to_h
    end

    raw['recaptcha_token'] = raw['g-recaptcha-response'] if raw['recaptcha_token'].blank? && raw['g-recaptcha-response'].present?
    raw.symbolize_keys
  end

  def render_contact_response(message, status: :ok)
    respond_to do |format|
      format.json { render json: { message: message }, status: status }
      format.any { render plain: message, status: status }
    end
  end

  def inject_contact_bridge(html)
    return html if html.include?('data-xbolt-tenant-contact-bridge')

    site_key = ERB::Util.json_escape(tenant_recaptcha_site_key.to_s)
    script = <<~HTML
      <script data-xbolt-tenant-contact-bridge>
      (function () {
        var endpoint = "/contact";
        var recaptchaSiteKey = "#{site_key}";
        var recaptchaAction = "#{TENANT_RECAPTCHA_ACTION}";
        var recaptchaScriptPromise = null;
        var forms = Array.prototype.slice.call(document.forms || []);
        if (!forms.length) return;

        function pick(form, selectors) {
          for (var i = 0; i < selectors.length; i++) {
            var el = form.querySelector(selectors[i]);
            if (el && typeof el.value === "string") return el.value.trim();
          }
          return "";
        }

        function loadRecaptchaScript() {
          if (!recaptchaSiteKey) return Promise.resolve();
          if (window.grecaptcha && window.grecaptcha.execute) return Promise.resolve();
          if (recaptchaScriptPromise) return recaptchaScriptPromise;

          recaptchaScriptPromise = new Promise(function (resolve, reject) {
            var script = document.createElement("script");
            script.src = "https://www.google.com/recaptcha/api.js?render=" + encodeURIComponent(recaptchaSiteKey);
            script.async = true;
            script.defer = true;
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
          });

          return recaptchaScriptPromise;
        }

        function getRecaptchaToken() {
          if (!recaptchaSiteKey) return Promise.resolve("");

          return loadRecaptchaScript().then(function () {
            return new Promise(function (resolve, reject) {
              if (!window.grecaptcha || !window.grecaptcha.ready || !window.grecaptcha.execute) {
                reject(new Error("reCAPTCHA is unavailable."));
                return;
              }

              window.grecaptcha.ready(function () {
                window.grecaptcha.execute(recaptchaSiteKey, { action: recaptchaAction }).then(resolve).catch(reject);
              });
            });
          });
        }

        forms.forEach(function (form) {
          var action = (form.getAttribute("action") || "").trim().toLowerCase();
          var hasCoreFields =
            !!form.querySelector('input[name="name"], input[name="full_name"], input[name*="name"]') &&
            !!form.querySelector('input[name="email"], input[type="email"]') &&
            !!form.querySelector('textarea[name="message"], textarea');

          var normalizedAction = action.replace(window.location.origin.toLowerCase(), "");
          var isContactAction = normalizedAction === "/contact" || normalizedAction === "contact";
          var shouldBridge = action.indexOf("mailto:") === 0 || isContactAction || (hasCoreFields && (action === "" || action === "#"));
          if (!shouldBridge) return;

          if (!form.querySelector('input[name="website"]')) {
            var honeypot = document.createElement("input");
            honeypot.type = "text";
            honeypot.name = "website";
            honeypot.tabIndex = -1;
            honeypot.autocomplete = "off";
            honeypot.setAttribute("aria-hidden", "true");
            honeypot.style.position = "absolute";
            honeypot.style.left = "-10000px";
            form.appendChild(honeypot);
          }

          form.addEventListener("submit", function (event) {
            event.preventDefault();
            event.stopImmediatePropagation();

            var payload = {
              name: pick(form, ['input[name="name"]', 'input[name="full_name"]', 'input[name*="name"]']),
              email: pick(form, ['input[name="email"]', 'input[type="email"]']),
              phone: pick(form, ['input[name="phone"]', 'input[type="tel"]']),
              message: pick(form, ['textarea[name="message"]', "textarea"]),
              website: pick(form, ['input[name="website"]'])
            };

            getRecaptchaToken().then(function (token) {
              payload.recaptcha_token = token;
              return fetch(endpoint, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "Accept": "application/json"
              },
              body: JSON.stringify(payload)
              });
            })
              .then(function (response) {
                return response.json().catch(function () { return {}; }).then(function (data) {
                  return { ok: response.ok, message: data.message };
                });
              })
              .then(function (result) {
                alert(result.message || (result.ok ? "Message sent." : "Could not send message."));
                if (result.ok) form.reset();
              })
              .catch(function () {
                alert("Could not send message right now. Please try again later.");
              });
          }, true);
        });
      })();
      </script>
    HTML

    if html.include?('</body>')
      html.sub('</body>', "#{script}\n</body>")
    else
      "#{html}\n#{script}"
    end
  end

  def tenant_recaptcha_site_key
    ENV['TENANT_RECAPTCHA_SITE_KEY'].presence || ENV['GOOGLE_RECAPTCHA_SITE_KEY'].presence
  end

  def tenant_recaptcha_secret_key
    ENV['TENANT_RECAPTCHA_SECRET_KEY'].presence || ENV['GOOGLE_RECAPTCHA_SECRET_KEY'].presence
  end

  def tenant_recaptcha_enabled?
    tenant_recaptcha_site_key.present? && tenant_recaptcha_secret_key.present?
  end

  def tenant_recaptcha_min_score
    ENV.fetch('TENANT_RECAPTCHA_MIN_SCORE', '0.5').to_f
  end

  def verify_tenant_recaptcha(token, ip:)
    return { success: true, reason: 'recaptcha_not_configured' } unless tenant_recaptcha_enabled?
    return { success: false, reason: 'missing_recaptcha_token' } if token.blank?

    request = Net::HTTP::Post.new(TENANT_RECAPTCHA_VERIFY_URL)
    request.set_form_data(
      secret: tenant_recaptcha_secret_key,
      response: token.to_s,
      remoteip: ip.to_s
    )

    response = Net::HTTP.start(
      TENANT_RECAPTCHA_VERIFY_URL.host,
      TENANT_RECAPTCHA_VERIFY_URL.port,
      use_ssl: true,
      open_timeout: 3,
      read_timeout: 5
    ) { |http| http.request(request) }

    payload = JSON.parse(response.body)
    score = payload['score'].to_f
    action = payload['action'].to_s
    success = payload['success'] == true &&
      action == TENANT_RECAPTCHA_ACTION &&
      score >= tenant_recaptcha_min_score

    {
      success: success,
      reason: success ? 'recaptcha_passed' : "recaptcha_failed:#{Array(payload['error-codes']).join('|').presence || 'low_score_or_action_mismatch'}",
      score: score,
      action: action
    }
  rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError => e
    Rails.logger.warn("Tenant contact reCAPTCHA verification error: #{e.class}: #{e.message}")
    { success: false, reason: 'recaptcha_verification_error' }
  end

  def inject_gallery_bridge(html)
    return html if html.include?('data-xbolt-tenant-gallery-bridge')

    script = <<~HTML
      <script data-xbolt-tenant-gallery-bridge>
      (function () {
        function toMediaEl(asset) {
          var type = (asset.content_type || "").toLowerCase();
          if (type.indexOf("video/") === 0) {
            var video = document.createElement("video");
            video.controls = true;
            video.preload = "metadata";
            video.src = asset.url;
            video.style.width = "100%";
            video.style.height = "auto";
            video.style.borderRadius = "12px";
            return video;
          }

          var img = document.createElement("img");
          img.src = asset.url;
          img.alt = asset.filename || "gallery image";
          img.loading = "lazy";
          img.style.width = "100%";
          img.style.height = "auto";
          img.style.borderRadius = "12px";
          return img;
        }

        function renderInto(container, assets) {
          if (!container) return;
          container.innerHTML = "";
          assets.forEach(function (asset) {
            var item = document.createElement("div");
            item.className = "xbolt-gallery-item";
            item.setAttribute("data-category", asset.category || "general");
            item.setAttribute("data-title", asset.title || "");
            item.appendChild(toMediaEl(asset));
            container.appendChild(item);
          });
        }

        var targets = Array.prototype.slice.call(document.querySelectorAll("[data-xbolt-gallery]"));
        if (!targets.length) return;

        function loadTarget(target) {
          var category = (target.getAttribute("data-xbolt-gallery-category") || "").trim();
          var endpoint = "/xbolt/gallery.json";
          if (category) endpoint += "?category=" + encodeURIComponent(category);

          fetch(endpoint, { headers: { Accept: "application/json" } })
            .then(function (r) { return r.json(); })
            .then(function (payload) {
              var assets = (payload && payload.assets) || [];
              renderInto(target, assets);
            })
            .catch(function () { /* no-op */ });
        }

        targets.forEach(loadTarget);
      })();
      </script>
    HTML

    if html.include?('</body>')
      html.sub('</body>', "#{script}\n</body>")
    else
      "#{html}\n#{script}"
    end
  end

  def inject_event_tracking_bridge(html)
    return html if html.include?('data-xbolt-tenant-event-bridge')

    script = <<~HTML
      <script data-xbolt-tenant-event-bridge>
      (function () {
        function sendEvent(eventName, path) {
          var payload = JSON.stringify({ event: eventName, path: path || window.location.pathname });
          if (navigator.sendBeacon) {
            var blob = new Blob([payload], { type: "application/json" });
            navigator.sendBeacon("/xbolt/events", blob);
            return;
          }

          fetch("/xbolt/events", {
            method: "POST",
            headers: { "Content-Type": "application/json", "Accept": "application/json" },
            body: payload,
            keepalive: true
          }).catch(function () {});
        }

        document.addEventListener("click", function (event) {
          var target = event.target;
          if (!target || !target.closest) return;
          var link = target.closest('a[href^="tel:"]');
          if (!link) return;
          sendEvent("phone_click", window.location.pathname);
        }, { passive: true });
      })();
      </script>
    HTML

    if html.include?('</body>')
      html.sub('</body>', "#{script}\n</body>")
    else
      "#{html}\n#{script}"
    end
  end

  def tenant_rate_limit_key_ip(business:, ip:)
    "tenant_contact_rate_limit:#{business.id}:#{ip}"
  end

  def tenant_rate_limit_key_email(business:, email:)
    normalized = email.to_s.strip.downcase.gsub(/[^a-z0-9@._+\-]/i, '')
    "tenant_contact_rate_limit_email:#{business.id}:#{normalized}"
  end

  def tenant_rate_limited?(business:, ip:, email:)
    Rails.cache.read(tenant_rate_limit_key_ip(business: business, ip: ip)).present? ||
      Rails.cache.read(tenant_rate_limit_key_email(business: business, email: email)).present?
  end

  def mark_tenant_rate_limit!(business:, ip:, email:)
    Rails.cache.write(tenant_rate_limit_key_ip(business: business, ip: ip), true, expires_in: 15.minutes)
    Rails.cache.write(tenant_rate_limit_key_email(business: business, email: email), true, expires_in: 15.minutes)
  end

  def tenant_hourly_counter_key(business:)
    "tenant_contact_hourly_counter:#{business.id}:#{Time.current.utc.strftime('%Y%m%d%H')}"
  end

  def tenant_hourly_burst_limited?(business:)
    Rails.cache.read(tenant_hourly_counter_key(business: business)).to_i >= TENANT_CONTACT_BURST_LIMIT_PER_HOUR
  end

  def increment_tenant_hourly_counter!(business:)
    key = tenant_hourly_counter_key(business: business)
    current = Rails.cache.read(key).to_i
    Rails.cache.write(key, current + 1, expires_in: 70.minutes)
  end

  def track_tenant_event!(business, event_name)
    PageView.create(
      business: business,
      event_name: event_name,
      path: request.path.to_s[0, 500],
      host: request.host.to_s,
      referrer: request.referer,
      referrer_domain: safe_referrer_domain(request.referer),
      user_agent: request.user_agent,
      device_type: detect_device_type(request.user_agent),
      browser: detect_browser(request.user_agent),
      os: detect_os(request.user_agent),
      country_code: (request.headers['CF-IPCountry'].presence || request.headers['X-Country-Code'].presence)&.to_s&.upcase,
      ip_hash: request.remote_ip.to_s,
      occurred_at: Time.current
    )
  rescue StandardError
    nil
  end

end

