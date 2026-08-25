/**
 * MIGUEL ÁNGEL VALENCIA ORTIZ — PORTFOLIO INTERACTION ENGINE
 */

document.addEventListener('DOMContentLoaded', () => {
  // 1. Mobile Navigation Toggle
  const navToggle = document.getElementById('navToggle');
  const navMenu = document.getElementById('navMenu');
  const navLinks = document.querySelectorAll('.nav-link');

  if (navToggle && navMenu) {
    navToggle.addEventListener('click', () => {
      navMenu.classList.toggle('open');
      const isOpen = navMenu.classList.contains('open');
      navToggle.setAttribute('aria-expanded', isOpen);
      navToggle.innerHTML = isOpen ? '✕' : '☰';
    });

    navLinks.forEach(link => {
      link.addEventListener('click', () => {
        navMenu.classList.remove('open');
        if (navToggle) {
          navToggle.innerHTML = '☰';
        }
      });
    });
  }

  // 2. Active Navigation Spy on Scroll
  const sections = document.querySelectorAll('section[id]');
  window.addEventListener('scroll', () => {
    const scrollY = window.pageYOffset;
    sections.forEach(current => {
      const sectionHeight = current.offsetHeight;
      const sectionTop = current.offsetTop - 120;
      const sectionId = current.getAttribute('id');
      const navItem = document.querySelector(`.nav-link[href*="${sectionId}"]`);

      if (scrollY > sectionTop && scrollY <= sectionTop + sectionHeight) {
        if (navItem) navItem.classList.add('active');
      } else {
        if (navItem) navItem.classList.remove('active');
      }
    });
  });

  // 3. Quick Copy to Clipboard Handler
  const copyButtons = document.querySelectorAll('[data-copy]');
  copyButtons.forEach(button => {
    button.addEventListener('click', async (e) => {
      e.preventDefault();
      const textToCopy = button.getAttribute('data-copy');
      try {
        await navigator.clipboard.writeText(textToCopy);
        const originalText = button.innerHTML;
        button.innerHTML = '✓ ¡Copiado!';
        button.style.borderColor = 'var(--success)';
        setTimeout(() => {
          button.innerHTML = originalText;
          button.style.borderColor = '';
        }, 2000);
      } catch (err) {
        console.error('Error al copiar:', err);
      }
    });
  });

  // 4. Contact Form to WhatsApp & Direct Email Trigger
  const contactForm = document.getElementById('contactForm');
  if (contactForm) {
    contactForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const name = document.getElementById('formName').value.trim();
      const email = document.getElementById('formEmail').value.trim();
      const message = document.getElementById('formMessage').value.trim();

      const text = `Hola Miguel, soy ${name} (${email}). ${message}`;
      const whatsappUrl = `https://wa.me/593997631577?text=${encodeURIComponent(text)}`;
      
      // Open WhatsApp direct chat
      window.open(whatsappUrl, '_blank');
    });
  }
});
