'use strict';
// Runs production interaction logic in an isolated DOM fixture. This is not a
// browser/rendering test; use Chrome visual QA separately when tools are present.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test} = require('node:test');
const root = path.resolve(__dirname, '..');
const sample = JSON.parse(fs.readFileSync(path.join(root, 'public/lesson-sample.json'), 'utf8'));
class Element {
  constructor(dataset = {}) {
    this.dataset = dataset; this.attributes = {}; this.events = {}; this.children = [];
    this.disabled = false; this.value = ''; this._text = ''; this.classes = new Set();
    this.classList = {add: value => this.classes.add(value), toggle: (value, enabled) => {
      const add = enabled ?? !this.classes.has(value);
      if (add) this.classes.add(value); else this.classes.delete(value);
    }};
  }
  set textContent(value) {this._text = value; this.children = [];}
  get textContent() {return this._text + this.children.map(child => child.textContent).join('');}
  setAttribute(key, value) {this.attributes[key] = value;}
  addEventListener(name, handler) {(this.events[name] ??= []).push(handler);}
  async fire(name, event = {}) {for (const handler of this.events[name] ?? []) await handler(event);}
  replaceChildren(...children) {this.children = children; this._text = '';}
  append(...children) {this.children.push(...children);}
  closest() {return null;}
}
function site({offline = false, storageBlocked = false} = {}) {
  const html = fs.readFileSync(path.join(root, 'public/index.html'), 'utf8');
  const documentRoot = new Element(); documentRoot.dataset.theme = 'blush';
  const themes = [...html.matchAll(/data-theme-choice="([^"]+)"[^>]*><i[^>]*><\/i><span>([^<]+)<\/span>/g)].map(match => {
    const element = new Element({themeChoice: match[1]}); const label = new Element(); label.textContent = match[2];
    element.querySelector = () => label; return element;
  });
  const cardButtons = Array.from({length: 4}, (_, card) => new Element({card: String(card)}));
  const steps = Array.from({length: 4}, (_, step) => new Element({step: String(step)}));
  const segments = Array.from({length: 4}, () => new Element());
  const ids = Object.fromEntries(['reading-card','sample-prev','sample-next','sample-body','sample-kind','sample-count','sample-reference','sample-title','theme-name','chapter-picks','chapter-image','chapter-caption'].map(id => ['#' + id, new Element()]));
  const note = new Element(), meta = new Element();
  ids['#sample-body'].textContent = sample.verse;
  ids['#reading-card'].querySelectorAll = () => segments;
  const document = {documentElement: documentRoot, hidden: false,
    querySelector: selector => ids[selector] ?? (selector === '.sample-note' ? note : selector.startsWith('meta[') ? meta : null),
    querySelectorAll: selector => selector === '[data-theme-choice]' ? themes : selector === '[data-card]' ? cardButtons : selector === '[data-step]' ? steps : [],
    createElement: () => new Element(), addEventListener() {}};
  const saved = new Map();
  const context = {document, window: {innerWidth: 390, matchMedia: () => ({matches: true})},
    localStorage: {getItem: key => {if (storageBlocked) throw new Error('blocked'); return saved.get(key);},
      setItem: (key, value) => {if (storageBlocked) throw new Error('blocked'); saved.set(key, value);}},
    fetch: async url => {if (offline) throw new Error('offline'); return {ok: true, json: async () =>
      url === '/chapters.json' ? JSON.parse(fs.readFileSync(path.join(root, 'public/chapters.json'), 'utf8')) : sample};},
    getComputedStyle: () => ({getPropertyValue: () => '#fff8f6'}), performance: {now: () => 1000},
    requestAnimationFrame() {throw new Error('Canvas should be absent in this fixture');}};
  vm.runInNewContext(fs.readFileSync(path.join(root, 'public/site.js'), 'utf8'), context);
  return {ids, themes, cardButtons, steps, segments, documentRoot, saved, note, meta};
}
const flush = () => new Promise(resolve => setImmediate(resolve));
test('website chapter inventory follows the canonical five-day source and available images', () => {
  const source = JSON.parse(fs.readFileSync(path.join(root, 'content/units.json'), 'utf8'));
  const published = JSON.parse(fs.readFileSync(path.join(root, 'public/chapters.json'), 'utf8'));
  assert.equal(published.chapters.length, 73);
  source.forEach((chapter, index) => {
    const row = published.chapters[index];
    assert.equal(row.id, chapter.id);
    assert.equal(row.title, chapter.title);
    assert.equal(row.firstDay, chapter.firstDay);
    assert.equal(row.lastDay, chapter.lastDay);
    if (row.landscape) assert.ok(fs.existsSync(path.join(root, 'public', row.landscape.slice(1))));
  });
});
test('all available chapter photographs can be selected', async () => {
  const state = site(); await flush();
  const published = JSON.parse(fs.readFileSync(path.join(root, 'public/chapters.json'), 'utf8'));
  const available = published.chapters.filter(chapter => chapter.landscape);
  const buttons = state.ids['#chapter-picks'].children;
  assert.equal(buttons.length, available.length);
  await buttons.at(-1).fire('click');
  assert.equal(state.ids['#chapter-image'].src, available.at(-1).landscape);
  assert.equal(state.ids['#chapter-caption'].textContent,
    `Chapter ${String(available.length).padStart(2, '0')} · ${available.at(-1).title}`);
  assert.equal(buttons[0].attributes['aria-pressed'], 'false');
  assert.equal(buttons.at(-1).attributes['aria-pressed'], 'true');
});
test('website sample matches the active authored Day 1 record', () => {
  const catalog = JSON.parse(fs.readFileSync(path.join(root, 'content/lessons_v2.json'), 'utf8'));
  assert.deepEqual(sample, catalog[0]);
});
test('four-card sample supports buttons, arrow keys, swipes and state at the ends', async () => {
  const state = site(); await flush();
  assert.equal(state.ids['#sample-body'].textContent, sample.verse);
  assert.equal(state.ids['#sample-prev'].disabled, true);
  assert.equal(state.ids['#sample-next'].disabled, false);
  for (let index = 1; index <= 3; index++) {
    await state.ids['#sample-next'].fire('click');
    assert.equal(state.ids['#sample-count'].textContent, `${index + 1} / 4`);
  }
  assert.equal(state.ids['#sample-body'].textContent, sample.prayer);
  assert.equal(state.ids['#sample-next'].disabled, true);
  await state.cardButtons[1].fire('click');
  assert.equal(state.ids['#sample-body'].textContent, sample.meaning);
  let prevented = false;
  await state.ids['#reading-card'].fire('keydown', {key: 'ArrowRight', preventDefault() {prevented = true;}});
  assert.equal(prevented, true);
  assert.equal(state.ids['#sample-body'].textContent, sample.heart);
  await state.ids['#reading-card'].fire('pointerdown', {target: new Element(), clientX: 200});
  await state.ids['#reading-card'].fire('pointerup', {clientX: 100});
  assert.equal(state.ids['#sample-body'].textContent, sample.prayer);
  assert.equal(state.cardButtons[3].attributes['aria-pressed'], 'true');
  assert.equal(state.steps[3].classes.has('active'), true);
  assert.equal(state.segments[3].classes.has('active'), true);
});
test('all eight themes change the page and persist the selected theme', async () => {
  const state = site(); await flush(); assert.equal(state.themes.length, 8);
  for (const theme of state.themes) {
    await theme.fire('click');
    assert.equal(state.documentRoot.dataset.theme, theme.dataset.themeChoice);
    assert.equal(theme.attributes['aria-pressed'], 'true');
    assert.equal(state.saved.get('holyhim-site-theme'), theme.dataset.themeChoice);
  }
  assert.equal(state.ids['#theme-name'].textContent, 'Starlight');
  assert.equal(state.meta.attributes.content, '#fff8f6');
});
test('offline sample keeps Scripture readable and storage restrictions do not stop themes', async () => {
  const state = site({offline: true, storageBlocked: true}); await flush();
  assert.equal(state.ids['#sample-body'].textContent, sample.verse);
  assert.equal(state.ids['#sample-next'].disabled, true);
  assert.equal(state.note.textContent, 'Day 1 · A word to carry into your day.');
  await state.themes[6].fire('click');
  assert.equal(state.documentRoot.dataset.theme, 'midnight-rose');
});
async function support(response) {
  const button = new Element(), status = new Element(), form = new Element();
  const values = {email: 'reader@example.test', message: 'Please help me change my reminder.', website: ''};
  let request, resets = 0, timeout;
  form.querySelector = selector => selector === '.status' ? status : button;
  form.reset = () => {resets++;};
  class FormDataFixture {constructor() {return Object.entries(values);}}
  vm.runInNewContext(fs.readFileSync(path.join(root, 'public/support.js'), 'utf8'), {
    document: {querySelector: () => form}, FormData: FormDataFixture, AbortController,
    setTimeout: (callback, delay) => {timeout = delay; return 1;}, clearTimeout() {},
    fetch: async (url, options) => {request = {url, options}; if (response instanceof Error) throw response; return response;}
  });
  await form.fire('submit', {preventDefault() {}});
  return {button, status, request, resets, values, timeout};
}
test('support sends the exact JSON payload and restores the button after success', async () => {
  const state = await support({ok: true});
  assert.equal(state.request.url, '/api/support');
  assert.equal(state.request.options.method, 'POST');
  assert.deepEqual(JSON.parse(state.request.options.body), state.values);
  assert.equal(state.timeout, 12000);
  assert.equal(state.resets, 1); assert.equal(state.button.disabled, false);
  assert.match(state.status.textContent, /has been received/);
});
test('support preserves the message after rate limiting and connection failure', async () => {
  for (const response of [{ok: false, status: 429}, new Error('offline')]) {
    const state = await support(response);
    assert.equal(state.resets, 0); assert.equal(state.button.disabled, false);
    assert.match(state.status.textContent, response instanceof Error ? /Check your connection/ : /wait a little/);
  }
});
test('primary button text meets normal-text contrast in all eight themes', () => {
  const css = fs.readFileSync(path.join(root, 'public/style.css'), 'utf8');
  const declarations = block => Object.fromEntries([...block.matchAll(/(--[\w-]+)\s*:\s*([^;}]+)/g)].map(match => [match[1], match[2].trim()]));
  const defaults = Object.assign({}, ...[...css.matchAll(/:root\s*\{([^}]+)\}/g)].map(match => declarations(match[1])));
  const themes = new Map(['blush','rose','lavender','sunrise','pearl','sage','midnight-rose','starlight'].map(theme => [theme, {...defaults}]));
  for (const match of css.matchAll(/html\[data-theme=([\w-]+)\]\s*\{([^}]+)\}/g)) Object.assign(themes.get(match[1]) ?? {}, declarations(match[2]));
  function luminance(hex) {
    const values = [1,3,5].map(index => parseInt(hex.slice(index,index+2),16)/255).map(value => value <= .04045 ? value/12.92 : ((value+.055)/1.055)**2.4);
    return values.reduce((sum,value,index) => sum+value*[.2126,.7152,.0722][index],0);
  }
  function contrast(a,b) {const values=[luminance(a),luminance(b)].sort((a,b)=>a-b);return (values[1]+.05)/(values[0]+.05);}
  assert.match(css, /\.button\s*\{[^}]*background:\s*linear-gradient\([^;]*var\(--button-start\)/);
  assert.match(css, /\.button\s*\{[^}]*color:\s*var\(--button-ink\)/);
  for (const [name, variables] of themes) {
    for (const edge of ['--button-start','--button-end']) assert.ok(contrast(variables['--button-ink'],variables[edge]) >= 4.5, `${name}: ${edge}`);
  }
});
