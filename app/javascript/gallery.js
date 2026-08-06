// Enhanced gallery with load more and smooth lightbox
document.addEventListener('DOMContentLoaded', initGallery);
document.addEventListener('turbo:load', initGallery);

function initGallery() {
  const grid = document.querySelector('#gallery-grid');
  if (!grid) return;

  // Load More functionality
  const loadMoreBtn = document.getElementById('load-more-btn');
  if (loadMoreBtn) {
    let currentlyVisible = 9;
    const total = parseInt(loadMoreBtn.dataset.total) || 0;
    
    loadMoreBtn.addEventListener('click', () => {
      const hiddenItems = document.querySelectorAll('.gallery-item.hidden');
      const itemsToShow = Array.from(hiddenItems).slice(0, 9);
      
      itemsToShow.forEach((item, idx) => {
        setTimeout(() => {
          item.classList.remove('hidden');
          item.style.opacity = '0';
          item.style.transform = 'scale(0.9)';
          
          requestAnimationFrame(() => {
            item.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
            item.style.opacity = '1';
            item.style.transform = 'scale(1)';
          });
        }, idx * 50);
      });
      
      currentlyVisible += itemsToShow.length;
      
      const remaining = total - currentlyVisible;
      const countEl = document.getElementById('load-count');
      if (countEl) {
        countEl.textContent = `+${Math.min(remaining, 9)}`;
      }
      
      if (remaining <= 0) {
        loadMoreBtn.style.transform = 'scale(0)';
        loadMoreBtn.style.opacity = '0';
        setTimeout(() => loadMoreBtn.style.display = 'none', 300);
      }
      
      // Reinitialize lightbox items
      initLightbox();
    });
  }

  // Initialize lightbox
  initLightbox();
}

function initLightbox() {
  const getItems = () => Array.from(document.querySelectorAll('[data-gallery-item]:not(.hidden)'));
  const lightbox = document.getElementById('lightbox');
  const imgEl = document.getElementById('lightbox-img');
  const btnPrev = document.getElementById('lightbox-prev');
  const btnNext = document.getElementById('lightbox-next');
  const btnClose = document.getElementById('lightbox-close');
  const grid = document.getElementById('gallery-grid');
  
  if (!lightbox || !imgEl) return;
  
  let index = 0;
  let isTransitioning = false;

  const open = (i) => {
    if (isTransitioning) return;
    index = i;
    const items = getItems();
    const href = items[index]?.getAttribute('href');
    if (!href) return;
    
    // Fade in lightbox
    lightbox.classList.remove('hidden');
    lightbox.classList.add('flex');
    lightbox.style.opacity = '0';
    document.body.style.overflow = 'hidden';
    
    requestAnimationFrame(() => {
      lightbox.style.transition = 'opacity 0.3s ease';
      lightbox.style.opacity = '1';
    });
    
    // Load image with fade
    imgEl.style.opacity = '0';
    imgEl.style.transform = 'scale(0.95)';
    imgEl.src = href;
    
    imgEl.onload = () => {
      requestAnimationFrame(() => {
        imgEl.style.transition = 'opacity 0.3s ease, transform 0.3s ease';
        imgEl.style.opacity = '1';
        imgEl.style.transform = 'scale(1)';
      });
    };
    
    updateNavigationState();
  };
  
  const close = () => {
    if (isTransitioning) return;
    isTransitioning = true;
    
    lightbox.style.opacity = '0';
    imgEl.style.transform = 'scale(0.95)';
    
    setTimeout(() => {
      lightbox.classList.add('hidden');
      lightbox.classList.remove('flex');
      imgEl.src = '';
      imgEl.style.transform = 'scale(1)';
      document.body.style.overflow = '';
      isTransitioning = false;
    }, 300);
  };
  
  const next = () => {
    const items = getItems();
    if (isTransitioning || items.length === 0) return;
    isTransitioning = true;
    
    imgEl.style.transition = 'opacity 0.2s ease, transform 0.2s ease';
    imgEl.style.opacity = '0';
    imgEl.style.transform = 'translateX(-20px)';
    
    setTimeout(() => {
      index = (index + 1) % items.length;
      const href = items[index]?.getAttribute('href');
      imgEl.src = href;
      imgEl.style.transform = 'translateX(20px)';
      
      imgEl.onload = () => {
        requestAnimationFrame(() => {
          imgEl.style.opacity = '1';
          imgEl.style.transform = 'translateX(0)';
          setTimeout(() => isTransitioning = false, 200);
        });
      };
      
      updateNavigationState();
    }, 200);
  };
  
  const prev = () => {
    const items = getItems();
    if (isTransitioning || items.length === 0) return;
    isTransitioning = true;
    
    imgEl.style.transition = 'opacity 0.2s ease, transform 0.2s ease';
    imgEl.style.opacity = '0';
    imgEl.style.transform = 'translateX(20px)';
    
    setTimeout(() => {
      index = (index - 1 + items.length) % items.length;
      const href = items[index]?.getAttribute('href');
      imgEl.src = href;
      imgEl.style.transform = 'translateX(-20px)';
      
      imgEl.onload = () => {
        requestAnimationFrame(() => {
          imgEl.style.opacity = '1';
          imgEl.style.transform = 'translateX(0)';
          setTimeout(() => isTransitioning = false, 200);
        });
      };
      
      updateNavigationState();
    }, 200);
  };
  
  const updateNavigationState = () => {
    const items = getItems();
    if (btnPrev) btnPrev.style.opacity = items.length > 1 ? '1' : '0.3';
    if (btnNext) btnNext.style.opacity = items.length > 1 ? '1' : '0.3';
  };

  // Event delegation so newly revealed items also work
  if (grid) {
    grid.addEventListener('click', (e) => {
      const anchor = e.target.closest('[data-gallery-item]');
      if (!anchor) return;
      e.preventDefault();
      const items = getItems();
      const i = items.indexOf(anchor);
      if (i >= 0) open(i);
    }, { passive: false });
  }

  if (btnClose) {
    const newClose = btnClose.cloneNode(true);
    btnClose.parentNode.replaceChild(newClose, btnClose);
    newClose.addEventListener('click', close);
  }
  
  if (btnNext) {
    const newNext = btnNext.cloneNode(true);
    btnNext.parentNode.replaceChild(newNext, btnNext);
    newNext.addEventListener('click', next);
  }
  
  if (btnPrev) {
    const newPrev = btnPrev.cloneNode(true);
    btnPrev.parentNode.replaceChild(newPrev, btnPrev);
    newPrev.addEventListener('click', prev);
  }
  
  // Lightbox click to close
  lightbox.addEventListener('click', (e) => {
    if (e.target === lightbox) close();
  });

  // Keyboard support
  const keyHandler = (e) => {
    if (lightbox.classList.contains('hidden')) return;
    if (e.key === 'Escape') close();
    if (e.key === 'ArrowRight') next();
    if (e.key === 'ArrowLeft') prev();
  };
  
  document.removeEventListener('keydown', keyHandler);
  document.addEventListener('keydown', keyHandler);

  // Touch/swipe support
  let startX = 0;
  let startY = 0;
  
  imgEl.addEventListener('touchstart', (e) => {
    startX = e.touches[0].clientX;
    startY = e.touches[0].clientY;
  });
  
  imgEl.addEventListener('touchend', (e) => {
    const endX = e.changedTouches[0].clientX;
    const endY = e.changedTouches[0].clientY;
    const dx = endX - startX;
    const dy = endY - startY;
    
    // Only trigger if horizontal swipe is dominant
    if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 50) {
      if (dx > 0) prev();
      else next();
    }
  });
}


