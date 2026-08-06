// ===== INTRO / OPENING ANIMATION =====
(function() {
    const intro = document.getElementById('intro-overlay');
    if (!intro) return;

    const INTRO_DURATION = 3200;

    document.body.style.overflow = 'hidden';

    setTimeout(() => {
        intro.classList.add('hidden');
        document.body.style.overflow = '';
    }, INTRO_DURATION);
})();

// ===== HERO PARALLAX =====
document.addEventListener('DOMContentLoaded', () => {
    const heroSection = document.getElementById('hero-section');
    if (!heroSection) return;

    const heroContent = heroSection.querySelector('.relative.z-10');
    let ticking = false;

    function updateScrollParallax() {
        const scrolled = window.pageYOffset;
        const heroHeight = heroSection.offsetHeight;
        if (scrolled < heroHeight && heroContent) {
            const opacity = 1 - (scrolled / heroHeight) * 1.2;
            heroContent.style.opacity = Math.max(0, opacity);
        }
        ticking = false;
    }

    updateScrollParallax();
    window.addEventListener('scroll', () => {
        if (!ticking) {
            window.requestAnimationFrame(updateScrollParallax);
            ticking = true;
        }
    }, { passive: true });
});

// ===== NAVBAR BEHAVIOUR + MOBILE NAV =====
document.addEventListener('DOMContentLoaded', function() {
    const navbar = document.getElementById('navbar');
    const mobileMenuButton = document.getElementById('mobile-menu-button');
    if (!navbar) return;

    const startSolid = document.body.classList.contains('nav-solid-start');
    let lastScrollY = window.scrollY;

    function updateNavbarState() {
        const currentScrollY = window.scrollY;
        if (currentScrollY > 60 || startSolid) navbar.classList.add('scrolled');
        else navbar.classList.remove('scrolled');
        const delta = currentScrollY - lastScrollY;
        if (currentScrollY > 150 && delta > 5) navbar.classList.add('hidden-nav');
        else if (delta < -5 || currentScrollY <= 60) navbar.classList.remove('hidden-nav');
        lastScrollY = currentScrollY;
    }

    updateNavbarState();
    window.addEventListener('scroll', updateNavbarState, { passive: true });

    if (!mobileMenuButton) return;

    const overlay = document.createElement('div');
    overlay.className = 'fixed inset-0 bg-black/70 opacity-0 pointer-events-none transition-opacity duration-300 z-40';
    document.body.appendChild(overlay);

    const mobileMenu = document.createElement('div');
    mobileMenu.className = 'fixed top-0 right-0 h-full w-[300px] border-l transform translate-x-full transition-transform duration-300 ease-in-out z-50 flex flex-col justify-between p-8';
    mobileMenu.style.backgroundColor = '#000';
    mobileMenu.style.borderColor = 'rgba(0,212,255,0.08)';

    const topSection = document.createElement('div');
    topSection.className = 'w-full';

    const menuHeader = document.createElement('div');
    menuHeader.className = 'flex items-center justify-between mb-2';
    const menuTitle = document.createElement('span');
    menuTitle.className = 'text-sm font-medium text-white/60 uppercase';
    menuTitle.style.letterSpacing = '2px';
    menuTitle.textContent = 'MENU';
    menuHeader.appendChild(menuTitle);

    const closeButton = document.createElement('button');
    closeButton.className = 'text-white focus:outline-none hover:text-cyan-400 transition-colors';
    closeButton.innerHTML = '<i class="fas fa-times text-xl"></i>';
    menuHeader.appendChild(closeButton);
    topSection.appendChild(menuHeader);

    const links = [
        { text: 'Home', href: 'index.html' },
        { text: 'Reviews', href: 'reviews.html' },
        { text: "FAQ's", href: 'faq.html' },
        { text: 'Contact', href: 'contact.html' }
    ];

    const navLinks = document.createElement('div');
    navLinks.className = 'mt-12';
    links.forEach(link => {
        const a = document.createElement('a');
        a.href = link.href;
        a.className = 'block w-full py-4 text-base font-medium text-white/70 hover:text-cyan-400 transition-colors';
        a.style.borderBottom = '1px solid rgba(255,255,255,0.05)';
        a.textContent = link.text;
        navLinks.appendChild(a);
    });
    topSection.appendChild(navLinks);
    mobileMenu.appendChild(topSection);

    const bottomSection = document.createElement('div');
    bottomSection.className = 'w-full pb-4 space-y-3';

    const callLink = document.createElement('a');
    callLink.href = 'tel:07969360366';
    callLink.className = 'w-full inline-flex items-center justify-center gap-2 font-medium px-6 py-3 transition-all text-center text-black text-sm tracking-wide';
    callLink.style.background = '#00d4ff';
    callLink.innerHTML = '<i class="fas fa-phone-alt"></i> 07969 360366';
    bottomSection.appendChild(callLink);

    const quoteLink = document.createElement('a');
    quoteLink.href = 'contact.html';
    quoteLink.className = 'w-full inline-block font-medium px-6 py-3 text-center text-cyan-400 text-sm tracking-wide';
    quoteLink.style.border = '1px solid rgba(0,212,255,0.3)';
    quoteLink.textContent = 'Send Enquiry';
    bottomSection.appendChild(quoteLink);

    mobileMenu.appendChild(bottomSection);
    document.body.appendChild(mobileMenu);

    let isMenuOpen = false;
    function toggleMenu() {
        isMenuOpen = !isMenuOpen;
        mobileMenu.style.transform = isMenuOpen ? 'translateX(0)' : 'translateX(100%)';
        overlay.style.opacity = isMenuOpen ? '1' : '0';
        overlay.style.pointerEvents = isMenuOpen ? 'auto' : 'none';
        document.body.style.overflow = isMenuOpen ? 'hidden' : '';
    }

    mobileMenuButton.addEventListener('click', toggleMenu);
    closeButton.addEventListener('click', toggleMenu);
    overlay.addEventListener('click', toggleMenu);
    mobileMenu.querySelectorAll('a').forEach(l => l.addEventListener('click', () => { if (isMenuOpen) toggleMenu(); }));
    window.addEventListener('resize', () => { if (window.innerWidth >= 768 && isMenuOpen) toggleMenu(); });
});

// ===== CONTACT FORM HANDLER =====
document.addEventListener('DOMContentLoaded', () => {
    const contactForm = document.getElementById('contact-form');
    if (!contactForm) return;
    if (contactForm.dataset.submitHandlerBound === 'true') return;
    contactForm.dataset.submitHandlerBound = 'true';

    const submitButton = contactForm.querySelector('button[type="submit"]');
    const formWrapper = document.getElementById('contact-form-wrapper');
    const defaultButtonText = submitButton?.dataset.defaultText || 'Send Enquiry';
    let isSubmitting = false;

    contactForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (isSubmitting) return;
        isSubmitting = true;
        submitButton.disabled = true;
        submitButton.innerHTML = '<span class="inline-flex items-center gap-3"><svg class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>Sending...</span>';

        const showSuccess = () => {
            formWrapper.innerHTML = `
                <div class="flex flex-col items-center justify-center text-center py-16 px-8">
                    <div class="w-16 h-16 flex items-center justify-center mb-6" style="border: 1px solid rgba(0,212,255,0.2);">
                        <svg class="w-8 h-8" fill="none" stroke="#00d4ff" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                    </div>
                    <h4 class="font-heading text-3xl text-white mb-3" style="letter-spacing:2px;">Message Sent</h4>
                    <p class="text-gray-500">We'll be in touch shortly. If urgent, call <a href="tel:07969360366" class="text-cyan-400">07969 360366</a>.</p>
                </div>`;
        };

        try {
            const body = new URLSearchParams(new FormData(contactForm));
            await fetch('/contact', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body.toString(), redirect: 'manual' });
            showSuccess();
        } catch (_err) {
            isSubmitting = false;
            submitButton.disabled = false;
            submitButton.textContent = defaultButtonText;
            const errorEl = document.getElementById('form-error');
            if (errorEl) { errorEl.classList.remove('hidden'); setTimeout(() => errorEl.classList.add('hidden'), 6000); }
        }
    });
});

// ===== SMOOTH SCROLL =====
document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            const href = this.getAttribute('href');
            if (href === '#' || href === '') return;
            e.preventDefault();
            const target = document.querySelector(href);
            if (target) window.scrollTo({ top: target.offsetTop - 80, behavior: 'smooth' });
        });
    });
});
