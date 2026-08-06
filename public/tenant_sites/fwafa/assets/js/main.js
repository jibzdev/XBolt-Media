// ===== INITIALIZE HERO EFFECTS =====
document.addEventListener('DOMContentLoaded', () => {
    // Initialize scroll parallax
    initHeroParallax();
});

// ===== HERO PARALLAX SCROLL EFFECT (SIMPLIFIED) =====
function initHeroParallax() {
    const heroSection = document.getElementById('hero-section');
    if (!heroSection) return;
    
    const heroContent = heroSection.querySelector('.relative.z-10');
    
    let ticking = false;
    
    function updateScrollParallax() {
        const scrolled = window.pageYOffset;
        const heroHeight = heroSection.offsetHeight;
        
        if (scrolled < heroHeight && heroContent) {
            // Fade out content as user scrolls
            const opacity = 1 - (scrolled / heroHeight) * 1.2;
            heroContent.style.opacity = Math.max(0, opacity);
        }
        
        ticking = false;
    }
    
    // Initial call
    updateScrollParallax();
    
    // Update on scroll
    window.addEventListener('scroll', () => {
        if (!ticking) {
            window.requestAnimationFrame(updateScrollParallax);
            ticking = true;
        }
    }, { passive: true });
}

// Show loading animation when page starts loading
document.onreadystatechange = function() {
    if (document.readyState !== "complete") {
        // Create and add loading overlay
        const loadingOverlay = document.createElement('div');
        loadingOverlay.id = 'loading-overlay';
        loadingOverlay.innerHTML = `
            <div class="loading-container">
                <div class="scaffold-loader">
                    <div class="beam"></div>
                    <div class="beam"></div>
                    <div class="beam"></div>
                </div>
                <p>LOADING</p>
            </div>
        `;
        document.body.appendChild(loadingOverlay);
    }
};

// Remove loading animation when page is fully loaded
window.onload = function() {
    const loadingOverlay = document.getElementById('loading-overlay');
    if (loadingOverlay) {
        loadingOverlay.style.opacity = '0';
        loadingOverlay.style.transition = 'opacity 0.5s ease';
        // Remove overlay after fade completes
        setTimeout(() => {
            loadingOverlay.remove();
        }, 500);
    }
};

// Navbar scroll animation
document.addEventListener('DOMContentLoaded', function() {
    const navbar = document.getElementById('navbar');
    if (!navbar) return;
    
    let ticking = false;
    
    // Set initial state
    if (window.scrollY <= 50) {
        navbar.classList.remove('navbar-scrolled');
    } else {
        navbar.classList.add('navbar-scrolled');
    }
    
    // Update navbar on scroll
    function updateNavbar() {
        const scrollY = window.scrollY;
        
        if (scrollY > 50) {
            navbar.classList.add('navbar-scrolled');
        } else {
            navbar.classList.remove('navbar-scrolled');
        }
        
        ticking = false;
    }
    
    // Use passive scroll listener for better performance
    window.addEventListener('scroll', function() {
        if (!ticking) {
            window.requestAnimationFrame(updateNavbar);
            ticking = true;
        }
    }, { passive: true });
});

// Mobile Navigation
document.addEventListener('DOMContentLoaded', function() {
    const mobileMenuButton = document.getElementById('mobile-menu-button');
    
    if (!mobileMenuButton) {
        return;
    }
    
    // Create overlay
    const overlay = document.createElement('div');
    overlay.className = 'fixed inset-0 bg-black/80 opacity-0 pointer-events-none transition-opacity duration-300 z-40';
    document.body.appendChild(overlay);
    
    // Create mobile menu
    const mobileMenu = document.createElement('div');
    mobileMenu.className = 'fixed top-0 right-0 h-full w-[300px] bg-black border-l border-gold-500/20 transform translate-x-full transition-transform duration-300 ease-in-out z-50 flex flex-col justify-between p-8';
    
    // Create top section for nav links
    const topSection = document.createElement('div');
    topSection.className = 'w-full';
    
    // Add close button
    const closeButton = document.createElement('button');
    closeButton.className = 'absolute top-6 right-6 text-white focus:outline-none hover:text-gold-500 transition-colors';
    closeButton.innerHTML = '<i class="fas fa-times text-2xl"></i>';
    topSection.appendChild(closeButton);
    
    // Add navigation links
    const links = [
        { text: 'About', href: '/#about' },
        { text: 'Drone Services', href: '/drone-services.html' },
        { text: 'Gallery', href: '/gallery.html' },
        { text: 'Contact', href: '/contact.html' }
    ];
    
    // Create nav links container
    const navLinks = document.createElement('div');
    navLinks.className = 'mt-16';
    
    links.forEach(link => {
        const a = document.createElement('a');
        a.href = link.href;
        a.className = 'text-white hover:text-gold-500 transition-all duration-300 font-medium text-lg py-4 block w-full border-b border-gold-500/10';
        a.textContent = link.text;
        navLinks.appendChild(a);
    });
    
    topSection.appendChild(navLinks);
    mobileMenu.appendChild(topSection);
    
    // Create bottom section for quote button
    const bottomSection = document.createElement('div');
    bottomSection.className = 'w-full pb-8';
    
    // Add "Get a Quote" button
    const quoteLink = document.createElement('a');
    quoteLink.href = '#contact';
    quoteLink.className = 'w-full inline-block bg-gold-500 text-black font-semibold px-8 py-3 hover:bg-gold-400 transition-all duration-300 text-center';
    quoteLink.textContent = 'Get a Quote';
    bottomSection.appendChild(quoteLink);
    
    mobileMenu.appendChild(bottomSection);
    
    // Add menu to body
    document.body.appendChild(mobileMenu);
    
    // Toggle menu
    let isMenuOpen = false;
    
    function toggleMenu() {
        isMenuOpen = !isMenuOpen;
        mobileMenu.style.transform = isMenuOpen ? 'translateX(0)' : 'translateX(100%)';
        overlay.style.opacity = isMenuOpen ? '1' : '0';
        overlay.style.pointerEvents = isMenuOpen ? 'auto' : 'none';
        
        // Prevent body scrolling when menu is open
        document.body.style.overflow = isMenuOpen ? 'hidden' : '';
    }
    
    // Event listeners
    mobileMenuButton.addEventListener('click', toggleMenu);
    closeButton.addEventListener('click', toggleMenu);
    overlay.addEventListener('click', toggleMenu);
    
    // Close menu when clicking a link
    mobileMenu.querySelectorAll('a').forEach(link => {
        link.addEventListener('click', toggleMenu);
    });
    
    // Close menu on window resize if it would show desktop menu
    window.addEventListener('resize', () => {
        if (window.innerWidth >= 768 && isMenuOpen) {
            toggleMenu();
        }
    });
});

// Contact Form Handler
document.addEventListener('DOMContentLoaded', () => {
    const contactForm = document.getElementById('contact-form');
    if (!contactForm) {
        return;
    }

    const statusMessage = contactForm.querySelector('[data-status]');
    const errorList = contactForm.querySelector('[data-errors]');
    const submitButton = contactForm.querySelector('button[type="submit"]');
    const defaultButtonText = submitButton ? (submitButton.dataset.defaultText || submitButton.textContent) : '';
    const successClasses = ['text-gold-100', 'bg-gold-500/10', 'border-gold-500/20'];
    const errorClasses = ['text-red-200', 'bg-red-500/10', 'border-red-500/20'];
    const allowedServices = new Set(['dry-stone-walling', 'drone-surveying', 'landscaping', 'consultancy', 'site-survey', 'aerial-photography', '3d-modeling', 'construction-monitoring', 'other']);

    function resetMessages() {
        if (statusMessage) {
            statusMessage.classList.add('hidden');
            statusMessage.classList.remove(...errorClasses);
            statusMessage.classList.add(...successClasses);
            statusMessage.textContent = '';
        }

        if (errorList) {
            errorList.classList.add('hidden');
            errorList.innerHTML = '';
        }
    }

    function setButtonState(isLoading) {
        if (!submitButton) {
            return;
        }

        submitButton.disabled = isLoading;
        submitButton.classList.toggle('opacity-60', isLoading);
        submitButton.classList.toggle('cursor-not-allowed', isLoading);
        submitButton.textContent = isLoading ? 'Sending…' : defaultButtonText;
    }

    function showErrors(errors) {
        if (!errorList || !errors.length) {
            return;
        }

        errorList.innerHTML = '';
        errors.forEach(({ message }) => {
            const item = document.createElement('li');
            item.textContent = message;
            errorList.appendChild(item);
        });
        errorList.classList.remove('hidden');
    }

    function showStatus(message, type = 'success') {
        if (!statusMessage) {
            return;
        }

        statusMessage.textContent = message;
        statusMessage.classList.remove('hidden');

        if (type === 'error') {
            statusMessage.classList.remove(...successClasses);
            statusMessage.classList.add(...errorClasses);
        } else {
            statusMessage.classList.remove(...errorClasses);
            statusMessage.classList.add(...successClasses);
        }
    }

    function clientValidate(payload) {
        const errors = [];

        if (!payload.name) {
            errors.push({ field: 'name', message: 'Please enter your full name.' });
        } else if (payload.name.length > 80) {
            errors.push({ field: 'name', message: 'Name must be 80 characters or fewer.' });
        }

        if (!payload.email) {
            errors.push({ field: 'email', message: 'Please enter your email address.' });
        } else if (!/^\S+@\S+\.\S+$/.test(payload.email)) {
            errors.push({ field: 'email', message: 'Please provide a valid email address.' });
        }

        if (payload.phone && !/^[\d\s()+-]{7,20}$/.test(payload.phone)) {
            errors.push({ field: 'phone', message: 'Please provide a valid phone number.' });
        }

        if (!payload.service || !allowedServices.has(payload.service)) {
            errors.push({ field: 'service', message: 'Please select one of our services.' });
        }

        if (!payload.message || payload.message.length < 10) {
            errors.push({ field: 'message', message: 'Tell us a little more about your project (at least 10 characters).' });
        } else if (payload.message.length > 1000) {
            errors.push({ field: 'message', message: 'Message must be 1000 characters or fewer.' });
        }

        return errors;
    }

    contactForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        resetMessages();

        const formData = new FormData(contactForm);
        const payload = {
            name: (formData.get('name') || '').trim(),
            email: (formData.get('email') || '').trim(),
            phone: (formData.get('phone') || '').trim(),
            service: formData.get('service') || '',
            message: (formData.get('message') || '').trim(),
        };

        const clientErrors = clientValidate(payload);
        if (clientErrors.length) {
            showErrors(clientErrors);
            showStatus('Please fix the highlighted issues and try again.', 'error');
            return;
        }

		// Send via default mail client (no backend required)
		setButtonState(true);
		const subject = `New enquiry from ${payload.name} (${payload.service})`;
		const body = [
			`Name: ${payload.name}`,
			`Email: ${payload.email}`,
			payload.phone ? `Phone: ${payload.phone}` : null,
			`Service: ${payload.service}`,
			'',
			'Message:',
			payload.message,
		].filter(Boolean).join('\n');
		const mailtoLink = `mailto:info@dawkesdevelopments.com?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
		window.location.href = mailtoLink;
		showStatus('Your email app will open to send the message.');
		setButtonState(false);
		return;
    });
});

// Smooth scroll for anchor links
document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            const href = this.getAttribute('href');
            
            // Don't prevent default for empty hash or just '#'
            if (href === '#' || href === '') {
                return;
            }
            
            e.preventDefault();
            
            const target = document.querySelector(href);
            if (target) {
                const offsetTop = target.offsetTop - 80; // Account for fixed navbar
                window.scrollTo({
                    top: offsetTop,
                    behavior: 'smooth'
                });
            }
        });
    });
});
