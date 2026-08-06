document.addEventListener("DOMContentLoaded", () => {
    const cookieBanner = document.querySelector('#cookie-banner');
    const acceptCookiesButton = document.querySelector('#acceptCookies');
    const denyCookiesButton = document.querySelector('#denyCookies');

    if (localStorage.getItem('acceptCookies') === 'true' || localStorage.getItem('acceptCookies') === 'false') {
        cookieBanner.style.display = 'none';
    }

    acceptCookiesButton.addEventListener('click', () => {
        localStorage.setItem('acceptCookies', 'true');
        cookieBanner.remove();
    });

    denyCookiesButton.addEventListener('click', () => {
        localStorage.setItem('acceptCookies', 'false');
        cookieBanner.remove();
    });
});