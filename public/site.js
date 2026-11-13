(() => {
  'use strict';
  const root = document.documentElement;
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const themeButtons = [...document.querySelectorAll('[data-theme-choice]')];
  const knownThemes = new Set(themeButtons.map(button => button.dataset.themeChoice));
  let themeChanged = () => {};
  function selectTheme(id, persist = true) {
    if (!knownThemes.has(id)) return;
    root.dataset.theme = id;
    themeButtons.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.themeChoice === id)));
    const selected = themeButtons.find(button => button.dataset.themeChoice === id);
    const name = document.querySelector('#theme-name');
    if (name) name.textContent = selected.querySelector('span').textContent;
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', getComputedStyle(root).getPropertyValue('--bg').trim());
    if (persist) { try { localStorage.setItem('holyhim-site-theme', id); } catch (_) {} }
    themeChanged();
  }
  themeButtons.forEach(button => button.addEventListener('click', () => selectTheme(button.dataset.themeChoice)));
  try { selectTheme(localStorage.getItem('holyhim-site-theme'), false); } catch (_) {}

  const chapterPicks = document.querySelector('#chapter-picks');
  if (chapterPicks) {
    fetch('/chapters.json').then(response => response.ok ? response.json() : Promise.reject())
      .then(data => {
        const chapters = data.chapters.filter(chapter => chapter.landscape);
        const picture = document.querySelector('#chapter-image');
        const caption = document.querySelector('#chapter-caption');
        chapters.forEach((chapter, index) => {
          const button = document.createElement('button');
          button.type = 'button';
          button.textContent = `${String(index + 1).padStart(2, '0')} · ${chapter.title}`;
          button.setAttribute('aria-pressed', String(index === 0));
          button.addEventListener('click', () => {
            picture.src = chapter.landscape;
            picture.alt = `Photographic artwork for chapter ${index + 1}, ${chapter.title}.`;
            caption.textContent = `Chapter ${String(index + 1).padStart(2, '0')} · ${chapter.title}`;
            [...chapterPicks.children].forEach(item => item.setAttribute('aria-pressed', String(item === button)));
          });
          chapterPicks.append(button);
        });
      }).catch(() => { /* The first chapter remains visible offline. */ });
  }

  if ('IntersectionObserver' in window) {
    root.classList.add('js');
    const reveal = new IntersectionObserver(entries => entries.forEach(entry => {
      if (entry.isIntersecting) { entry.target.classList.add('visible'); reveal.unobserve(entry.target); }
    }), {threshold: .12, rootMargin: '0px 0px -25px 0px'});
    document.querySelectorAll('.reveal,.blur-reveal').forEach(element => reveal.observe(element));
  }

  const reader = document.querySelector('#reading-card');
  let lesson = null;
  let current = 0;
  let manualUntil = 0;
  const labels = ["TODAY'S WORD", 'WHAT IT MEANS', 'FOR YOUR HEART', 'PRAYER'];
  const cardButtons = [...document.querySelectorAll('[data-card]')];
  const steps = [...document.querySelectorAll('[data-step]')];
  const previous = document.querySelector('#sample-prev');
  const next = document.querySelector('#sample-next');
  const body = document.querySelector('#sample-body');
  const kind = document.querySelector('#sample-kind');
  const count = document.querySelector('#sample-count');
  const reference = document.querySelector('#sample-reference');
  function showCard(index, manual = false) {
    if (!reader || !lesson) return;
    current = Math.max(0, Math.min(3, index));
    if (manual) manualUntil = performance.now() + 4000;
    const values = [lesson.verse, lesson.meaning, lesson.heart, lesson.prayer];
    const text = document.createElement('p');
    text.textContent = values[current];
    body.replaceChildren(text);
    kind.textContent = labels[current];
    count.textContent = `${current + 1} / 4`;
    reference.textContent = current === 0 ? `${lesson.reference.toUpperCase()} · WEB` : 'DAY 01 · YOU DO NOT WALK ALONE';
    reader.classList.toggle('quote-card', false);
    cardButtons.forEach(button => button.setAttribute('aria-pressed', String(Number(button.dataset.card) === current)));
    steps.forEach(step => step.classList.toggle('active', Number(step.dataset.step) === current));
    reader.querySelectorAll('.story-segments i').forEach((segment, i) => segment.classList.toggle('active', i <= current));
    previous.disabled = current === 0;
    next.disabled = current === 3;
    if (!reducedMotion.matches && body.animate) body.animate([{opacity: .25, transform: 'translateY(7px)'}, {opacity: 1, transform: 'translateY(0)'}], {duration: 320, easing: 'cubic-bezier(.2,.7,.2,1)'});
  }
  if (reader) {
    fetch('/lesson-sample.json').then(response => response.ok ? response.json() : Promise.reject()).then(data => {
      lesson = data;
      document.querySelector('#sample-title').textContent = lesson.title;
      showCard(0);
    }).catch(() => {
      // The complete first verse is in the HTML. Keep it readable if offline.
      previous.disabled = true; next.disabled = true;
      document.querySelector('.sample-note').textContent = 'Day 1 · A word to carry into your day.';
    });
    cardButtons.forEach(button => button.addEventListener('click', () => showCard(Number(button.dataset.card), true)));
    previous.addEventListener('click', () => showCard(current - 1, true));
    next.addEventListener('click', () => showCard(current + 1, true));
    reader.addEventListener('keydown', event => {
      if (!['ArrowLeft','ArrowRight'].includes(event.key)) return;
      event.preventDefault(); showCard(current + (event.key === 'ArrowRight' ? 1 : -1), true);
    });
    let pointerX = null;
    reader.addEventListener('pointerdown', event => { if (event.target.closest('button')) return; pointerX = event.clientX; });
    reader.addEventListener('pointerup', event => {
      if (pointerX === null) return;
      const delta = event.clientX - pointerX; pointerX = null;
      if (Math.abs(delta) > 45) showCard(current + (delta < 0 ? 1 : -1), true);
    });
    reader.addEventListener('pointercancel', () => {pointerX = null;});
    if ('IntersectionObserver' in window) {
      const stepObserver = new IntersectionObserver(entries => {
        if (window.innerWidth <= 650 || performance.now() < manualUntil) return;
        const visible = entries.filter(entry => entry.isIntersecting).sort((a,b) => b.intersectionRatio - a.intersectionRatio);
        if (visible.length) showCard(Number(visible[0].target.dataset.step));
      }, {threshold: [.2,.5,.8], rootMargin: '-25% 0px -25% 0px'});
      steps.forEach(step => stepObserver.observe(step));
    }
  }

  const date = document.querySelector('.lock-date');
  if (date) date.textContent = new Intl.DateTimeFormat(undefined, {weekday:'long', month:'long', day:'numeric'}).format(new Date());

  const canvas = document.querySelector('#atmosphere');
  if (!canvas || !canvas.getContext) return;
  const context = canvas.getContext('2d', {alpha:false});
  if (!context) return;
  let width = 1, height = 1, frame = null, start = performance.now();
  let palette = [], oldPalette = [], morphAt = 0;
  const particles = Array.from({length:28}, (_, i) => ({x:((i * 37) % 101)/101, y:((i * 61) % 103)/103, radius:1 + (i % 4)*.5, phase:i*1.7}));
  function rgb(hex) {
    const value = hex.trim().replace('#','');
    return [parseInt(value.slice(0,2),16),parseInt(value.slice(2,4),16),parseInt(value.slice(4,6),16)];
  }
  function cssPalette() {
    const css = getComputedStyle(root);
    return ['--paper','--bg','--petal','--peach','--accent-soft'].map(key => rgb(css.getPropertyValue(key)));
  }
  function color(rgbValue, alpha = 1) { return `rgba(${rgbValue.map(value => Math.round(value)).join(',')},${alpha})`; }
  function fit() {
    const scale = Math.min(1, 1000/window.innerWidth);
    width = canvas.width = Math.round(window.innerWidth*scale);
    height = canvas.height = Math.round(window.innerHeight*scale);
    if (!frame) draw(performance.now());
  }
  themeChanged = () => {
    oldPalette = palette.length ? palette : cssPalette(); palette = cssPalette(); morphAt = performance.now();
    if (!frame) draw(performance.now());
  };
  palette = cssPalette(); oldPalette = palette;
  function draw(now) {
    frame = null;
    const seconds = reducedMotion.matches ? 5 : (now-start)/1000;
    const phase = seconds/20*Math.PI*2;
    const progress = reducedMotion.matches ? 1 : Math.min(1,(now-morphAt)/900);
    const colors = palette.map((c,i) => c.map((v,j) => oldPalette[i][j] + (v-oldPalette[i][j])*progress));
    const base = context.createLinearGradient(0,0,width,height);
    [0,.25,.5,.75,1].forEach((stop,i) => base.addColorStop(stop,color(colors[[0,1,2,3,0][i]])));
    context.fillStyle = base; context.fillRect(0,0,width,height);
    for (let i=0;i<4;i++) {
      const x=width*(.2+.6*(.5+.5*Math.sin(phase*.32+i*1.9)));
      const y=height*(.2+.65*(.5+.5*Math.cos(phase*.28+i*1.7)));
      const radius=Math.max(width,height)*(.4+i*.035);
      const glow=context.createRadialGradient(x,y,0,x,y,radius);
      glow.addColorStop(0,color(colors[(i+1)%4],.46));glow.addColorStop(1,color(colors[(i+1)%4],0));
      context.fillStyle=glow;context.fillRect(0,0,width,height);
    }
    particles.forEach(p => {
      const y=((p.y*height-seconds*height*.006)%height+height)%height;
      const x=p.x*width+Math.sin(seconds*.26+p.phase)*12;
      const twinkle=.16+.13*(.5+.5*Math.sin(seconds*.7+p.phase));
      const edge=Math.min(1,y/40,(height-y)/40);
      context.beginPath();context.fillStyle=color(colors[4],twinkle*edge);context.arc(x,y,p.radius,0,Math.PI*2);context.fill();
    });
    if (!reducedMotion.matches && !document.hidden) frame=requestAnimationFrame(draw);
  }
  window.addEventListener('resize', fit, {passive:true});
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && frame) {cancelAnimationFrame(frame);frame=null;}
    else if (!document.hidden && !frame) draw(performance.now());
  });
  reducedMotion.addEventListener?.('change', () => {if(frame)cancelAnimationFrame(frame);frame=null;draw(performance.now());});
  fit();
})();
