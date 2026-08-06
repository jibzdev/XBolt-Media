function onReady(fn) {
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn, { once: true });
  else fn();
}

onReady(boot);
document.addEventListener('turbo:load', boot);

function boot() {
  initSmartNavbar();
  initMobileNav();
  initScrollReveal();
  initHeroReveal();
  initHeroParallax();
  initFloatingCards();
  initStatCounters();
  initLightingSystem();
}

// Cancel any previous lighting animation before Turbo navigates away to avoid double-loops
document.addEventListener('turbo:before-render', function() {
  if (window.__xbLightingCancel) {
    try { window.__xbLightingCancel(); } catch (_) {}
    window.__xbLightingCancel = null;
  }
});

// ─── Smart Navbar ───
function initSmartNavbar() {
  var navbar = document.getElementById('navbar');
  var inner = document.getElementById('nav-inner');
  if (!navbar) return;

  var lastY = 0, hidden = false, ticking = false;

  setTimeout(function() {
    navbar.style.opacity = '1';
    navbar.style.transform = 'translateX(-50%) translateY(0)';
  }, 250);

  window.addEventListener('scroll', function() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function() {
      var y = window.scrollY;
      var delta = y - lastY;
      if (delta > 8 && y > 300 && !hidden) {
        hidden = true;
        navbar.style.transform = 'translateX(-50%) translateY(-120%)';
        navbar.style.opacity = '0';
      } else if (delta < -8 && hidden) {
        hidden = false;
        navbar.style.transform = 'translateX(-50%) translateY(0)';
        navbar.style.opacity = '1';
      }
      if (inner) {
        if (y > 80) {
          inner.style.borderColor = 'rgba(251,191,36,0.14)';
          inner.style.background = 'rgba(9,9,11,0.92)';
          inner.style.boxShadow = '0 8px 40px rgba(0,0,0,0.6), inset 0 1px 0 rgba(251,191,36,0.04)';
        } else {
          inner.style.borderColor = 'rgba(251,191,36,0.08)';
          inner.style.background = 'rgba(9,9,11,0.7)';
          inner.style.boxShadow = '0 8px 32px rgba(0,0,0,0.4)';
        }
      }
      lastY = y;
      ticking = false;
    });
  }, { passive: true });
}

// ─── Mobile nav ───
function initMobileNav() {
  var btn = document.getElementById('mobile-menu-btn');
  var sidebar = document.getElementById('mobile-sidebar');
  var overlay = document.getElementById('sidebar-overlay');
  var closeBtn = document.getElementById('close-sidebar');
  var open = false;
  if (!btn || !sidebar || !overlay) return;

  function show() {
    open = true;
    var y = window.pageYOffset || document.documentElement.scrollTop;
    document.body.classList.add('sidebar-open');
    overlay.style.pointerEvents = 'auto'; overlay.style.opacity = '1';
    sidebar.style.transform = 'translateX(0)';
    document.body.style.overflow = 'hidden'; document.body.style.position = 'fixed';
    document.body.style.top = '-' + y + 'px'; document.body.style.left = '0';
    document.body.style.right = '0'; document.body.style.width = '100%';
    document.body.dataset.scrollY = y.toString();
  }
  function hide() {
    open = false;
    document.body.classList.remove('sidebar-open');
    overlay.style.opacity = '0'; overlay.style.pointerEvents = 'none';
    sidebar.style.transform = 'translateX(100%)';
    var y = parseInt(document.body.dataset.scrollY || '0', 10);
    document.body.style.position = ''; document.body.style.top = '';
    document.body.style.left = ''; document.body.style.right = '';
    document.body.style.width = ''; document.body.style.overflow = '';
    delete document.body.dataset.scrollY; window.scrollTo(0, y);
  }
  hide();
  btn.addEventListener('click', function() { open ? hide() : show(); });
  if (closeBtn) closeBtn.addEventListener('click', hide);
  overlay.addEventListener('click', hide);
  sidebar.querySelectorAll('a').forEach(function(a) { a.addEventListener('click', function() { if (open) hide(); }); });
  window.addEventListener('resize', function() { if (window.innerWidth > 1024 && open) hide(); });
  document.addEventListener('keydown', function(e) { if (e.key === 'Escape' && open) hide(); });
}

// ─── Scroll reveal (legacy + new [data-v] system) ───
function initScrollReveal() {
  var reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Legacy
  var legacy = document.querySelectorAll('[data-anim], [data-stagger]');
  if (legacy.length) {
    if (reducedMotion) { legacy.forEach(function(el) { el.classList.add('is-visible'); }); }
    else {
      var io1 = new IntersectionObserver(function(entries) {
        entries.forEach(function(e) {
          if (e.isIntersecting) { e.target.classList.add('is-visible'); io1.unobserve(e.target); }
        });
      }, { threshold: 0.08, rootMargin: '0px 0px -40px 0px' });
      legacy.forEach(function(el) { io1.observe(el); });
    }
  }

  // New [data-v] animation system
  var vItems = document.querySelectorAll('[data-v]');
  if (vItems.length) {
    if (reducedMotion) { vItems.forEach(function(el) { el.classList.add('is-v'); }); }
    else {
      var io2 = new IntersectionObserver(function(entries) {
        entries.forEach(function(e) {
          if (!e.isIntersecting) return;
          io2.unobserve(e.target);
          var delay = parseInt(e.target.getAttribute('data-delay') || '0', 10);
          if (delay > 0) {
            setTimeout(function() { e.target.classList.add('is-v'); }, delay);
          } else {
            e.target.classList.add('is-v');
          }
        });
      }, { threshold: 0.06, rootMargin: '0px 0px -30px 0px' });
      vItems.forEach(function(el) { io2.observe(el); });
    }
  }

  // [data-split] — split text into individual characters that animate in
  var splitEls = document.querySelectorAll('[data-split]');
  splitEls.forEach(function(el) {
    var text = el.textContent;
    el.textContent = '';
    el.style.overflow = 'hidden';
    for (var i = 0; i < text.length; i++) {
      var span = document.createElement('span');
      span.className = 'xb-char';
      span.textContent = text[i] === ' ' ? '\u00A0' : text[i];
      span.style.transitionDelay = (i * 30) + 'ms';
      el.appendChild(span);
    }
    if (reducedMotion) { el.classList.add('xb-char-done'); return; }
    var io3 = new IntersectionObserver(function(entries) {
      entries.forEach(function(e) {
        if (e.isIntersecting) { e.target.classList.add('xb-char-done'); io3.unobserve(e.target); }
      });
    }, { threshold: 0.3 });
    io3.observe(el);
  });
}

// ─── Hero stagger reveal ───
function initHeroReveal() {
  var root = document.getElementById('xb-hero-root');
  if (!root) return;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    root.classList.add('is-visible');
    return;
  }
  setTimeout(function() { root.classList.add('is-visible'); }, 300);
}

// ─── Hero parallax ───
function initHeroParallax() {
  var hero = document.querySelector('.xbolt-hero-section');
  if (!hero || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  var content = hero.querySelector('.xb-hero-content');

  window.addEventListener('scroll', function() {
    requestAnimationFrame(function() {
      var y = window.scrollY;
      var h = hero.offsetHeight;
      if (y > h * 1.3) return;
      var r = y / h;
      if (content) {
        content.style.transform = 'translateY(' + (y * 0.15) + 'px)';
        content.style.opacity = Math.max(0, 1 - r * 1.2);
      }
    });
  }, { passive: true });
}

// ─── Floating cards parallax ───
function initFloatingCards() {
  var cards = document.querySelectorAll('.xb-float-card');
  if (!cards.length) return;
  var reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Stagger the reveal
  cards.forEach(function(card, i) {
    var baseRotate = parseFloat(card.getAttribute('data-rotate')) || 0;
    card.style.transform = 'translateY(30px) rotate(' + baseRotate + 'deg)';
    setTimeout(function() {
      card.classList.add('is-shown');
      card.style.transform = 'rotate(' + baseRotate + 'deg)';
    }, 600 + i * 150);
  });

  if (reducedMotion) {
    cards.forEach(function(card) {
      card.classList.add('is-shown');
      card.style.transform = 'none';
    });
    return;
  }

  var hero = document.querySelector('.xbolt-hero-section');
  if (!hero) return;

  window.addEventListener('scroll', function() {
    requestAnimationFrame(function() {
      var y = window.scrollY;
      var heroH = hero.offsetHeight;
      if (y > heroH * 1.3) return;

      cards.forEach(function(card) {
        var speed = parseFloat(card.getAttribute('data-speed')) || 0.05;
        var baseRotate = parseFloat(card.getAttribute('data-rotate')) || 0;
        var offsetY = y * speed;
        var rotateShift = y * speed * 0.15;
        card.style.transform = 'translateY(' + (-offsetY) + 'px) rotate(' + (baseRotate + rotateShift) + 'deg)';
        card.style.opacity = Math.max(0, 1 - (y / heroH) * 1.5);
      });
    });
  }, { passive: true });
}

// ─── Stat counters ───
function initStatCounters() {
  var stats = document.querySelectorAll('.xb-stat');
  if (!stats.length) return;
  var io = new IntersectionObserver(function(entries) {
    entries.forEach(function(e) {
      if (!e.isIntersecting) return;
      io.unobserve(e.target);
      var el = e.target;
      var numEl = el.querySelector('.xb-stat-num');
      var barEl = el.querySelector('.xb-stat-bar');
      if (!numEl) return;
      var target = parseInt(numEl.getAttribute('data-target'), 10) || 0;
      var suffix = numEl.getAttribute('data-suffix') || '';
      var prefix = numEl.getAttribute('data-prefix') || '';
      var start = performance.now();
      el.classList.add('is-counting');
      function tick(now) {
        var p = Math.min((now - start) / 2000, 1);
        var e2 = 1 - Math.pow(1 - p, 4);
        numEl.textContent = prefix + Math.round(e2 * target) + suffix;
        if (barEl) barEl.style.width = (e2 * 100) + '%';
        if (p < 1) requestAnimationFrame(tick);
        else el.classList.add('is-done');
      }
      requestAnimationFrame(tick);
    });
  }, { threshold: 0.5 });
  stats.forEach(function(s) { io.observe(s); });
}

// ══════════════════════════════════════════════════════════
// HERO AMBIENT LIGHTING — minimal, scroll-reactive
// ══════════════════════════════════════════════════════════
function initLightingSystem() {
  var canvas = document.getElementById('xb-lighting-canvas');
  if (!canvas) return;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  if (window.__xbLightingCancel) {
    try { window.__xbLightingCancel(); } catch (_) {}
    window.__xbLightingCancel = null;
  }

  var hero = canvas.parentElement;
  var ctx = canvas.getContext('2d');
  var W, H, animId;
  var isMobile = window.innerWidth < 768;
  var DPR = Math.min(window.devicePixelRatio || 1, 2);

  var scrollY = 0, prevScrollY = 0, rawVel = 0, smoothVel = 0;
  var heroH = 1;

  function draw(ts) {
    var scrollRatio = Math.min(1, scrollY / Math.max(1, heroH));
    var breathe = Math.sin(ts * 0.00025);
    var vel = smoothVel;
    var dim = Math.min(W, H);

    // ── Primary orb: large, centered behind headline ──
    // Tracks scroll position — slides up and left as you scroll down
    // Grows and brightens when scrolling fast
    var px = W * (0.5 + breathe * 0.025 - scrollRatio * 0.15);
    var py = H * (0.42 - scrollRatio * 0.2 + breathe * 0.02);
    var pr = (isMobile ? 0.58 : 0.55) * dim * (1 + breathe * 0.03 + vel * 0.15);
    var pAlpha = 1 + vel * 1.2;

    var g1 = ctx.createRadialGradient(px, py, 0, px, py, pr);
    g1.addColorStop(0,    'rgba(255,255,255,' + (0.13 * pAlpha) + ')');
    g1.addColorStop(0.12, 'rgba(254,243,199,' + (0.10 * pAlpha) + ')');
    g1.addColorStop(0.35, 'rgba(251,191,36,' + (0.065 * pAlpha) + ')');
    g1.addColorStop(0.65, 'rgba(245,158,11,' + (0.02 * pAlpha) + ')');
    g1.addColorStop(1,    'rgba(217,119,6,0)');
    ctx.fillStyle = g1;
    ctx.fillRect(0, 0, W, H);

    // ── Secondary orb: offset accent for depth ──
    // Moves opposite to primary — slides down-right on scroll
    var sx = W * (0.7 + scrollRatio * 0.18 - breathe * 0.03);
    var sy = H * (0.55 + scrollRatio * 0.15 - breathe * 0.025);
    var sr = (isMobile ? 0.38 : 0.35) * dim * (1 + vel * 0.1);
    var sAlpha = 1 + vel * 1.0;

    var g2 = ctx.createRadialGradient(sx, sy, 0, sx, sy, sr);
    g2.addColorStop(0,   'rgba(252,211,77,' + (0.08 * sAlpha) + ')');
    g2.addColorStop(0.3, 'rgba(251,191,36,' + (0.045 * sAlpha) + ')');
    g2.addColorStop(0.7, 'rgba(245,158,11,' + (0.015 * sAlpha) + ')');
    g2.addColorStop(1,   'rgba(217,119,6,0)');
    ctx.fillStyle = g2;
    ctx.fillRect(0, 0, W, H);

    // ── Tertiary orb: left-side counterbalance ──
    // Drifts slightly down on scroll for asymmetric feel
    var tx = W * (0.22 - scrollRatio * 0.1 + breathe * 0.02);
    var ty = H * (0.32 + scrollRatio * 0.12);
    var tr = (isMobile ? 0.3 : 0.28) * dim * (1 + vel * 0.08);
    var tAlpha = 1 + vel * 0.8;

    var g3 = ctx.createRadialGradient(tx, ty, 0, tx, ty, tr);
    g3.addColorStop(0,   'rgba(254,243,199,' + (0.06 * tAlpha) + ')');
    g3.addColorStop(0.35,'rgba(251,191,36,' + (0.03 * tAlpha) + ')');
    g3.addColorStop(1,   'rgba(245,158,11,0)');
    ctx.fillStyle = g3;
    ctx.fillRect(0, 0, W, H);
  }

  // Bottom fade for clean section transition
  function drawBottomFade() {
    ctx.globalCompositeOperation = 'destination-out';
    var grad = ctx.createLinearGradient(0, H * 0.78, 0, H);
    grad.addColorStop(0, 'rgba(0,0,0,0)');
    grad.addColorStop(1, 'rgba(0,0,0,1)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, H * 0.78, W, H * 0.22);
  }

  function resize() {
    isMobile = window.innerWidth < 768;
    canvas.width = hero.offsetWidth * DPR;
    canvas.height = hero.offsetHeight * DPR;
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    W = hero.offsetWidth;
    H = hero.offsetHeight;
    heroH = H;
  }
  resize();
  var resizeTimer;
  window.addEventListener('resize', function() {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(resize, 100);
  });

  function onScroll() {
    var newY = window.scrollY || window.pageYOffset || document.documentElement.scrollTop || 0;
    rawVel = Math.max(rawVel, Math.abs(newY - prevScrollY));
    scrollY = newY;
    prevScrollY = newY;
  }
  window.addEventListener('scroll', onScroll, { passive: true });

  function loop(ts) {
    if (scrollY > heroH * 1.2) {
      animId = requestAnimationFrame(loop);
      rawVel *= 0.9;
      smoothVel *= 0.9;
      return;
    }

    var target = Math.min(rawVel / 60, 1);
    smoothVel += (target - smoothVel) * 0.06;
    rawVel *= 0.92;

    ctx.clearRect(0, 0, W, H);
    ctx.globalCompositeOperation = 'lighter';

    draw(ts);
    drawBottomFade();

    ctx.globalCompositeOperation = 'source-over';
    ctx.globalAlpha = 1;

    animId = requestAnimationFrame(loop);
  }

  animId = requestAnimationFrame(loop);

  window.__xbLightingCancel = function() {
    if (animId) cancelAnimationFrame(animId);
    window.removeEventListener('scroll', onScroll);
  };

  window.addEventListener('beforeunload', function() {
    if (window.__xbLightingCancel) window.__xbLightingCancel();
  });
}
