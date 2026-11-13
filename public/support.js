(() => {
  const form = document.querySelector('#support');
  if (!form) return;
  form.addEventListener('submit', async event => {
    event.preventDefault();
    const button = form.querySelector('button[type="submit"]');
    const status = form.querySelector('.status');
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000);
    button.disabled = true; status.textContent = 'Sending your message…';
    try {
      const response = await fetch('/api/support', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(Object.fromEntries(new FormData(form))),signal:controller.signal});
      if (!response.ok) {
        status.textContent = response.status === 429 ? 'Please wait a little before sending another message.' : 'Your message could not be sent. Please try again.';
        return;
      }
      form.reset(); status.textContent = 'Your message has been received. Thank you for reaching out.';
    } catch (_) {
      status.textContent = 'We could not send your message yet. Check your connection and try again.';
    } finally {
      clearTimeout(timeout); button.disabled = false;
    }
  });
})();
