'use strict';
// HolyHim's website as it is published from public/: every page is styled by
// the stylesheet it links, every local link resolves, the published data
// matches the source, and the support form behaves. Not a rendering test.
// HolyHim owns this file with public/; a HolyHer sync does not replace it.
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
test('website sample matches the active authored Day 1 record', () => {
  const catalog = JSON.parse(fs.readFileSync(path.join(root, 'content/lessons_v2.json'), 'utf8'));
  assert.deepEqual(sample, catalog[0]);
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
const pages = fs.readdirSync(path.join(root, 'public')).filter(name => name.endsWith('.html'));
const styles = fs.readFileSync(path.join(root, 'public/style.css'), 'utf8');
test('every page is one of the five and links the stylesheet', () => {
  assert.deepEqual(pages.sort(), ['404.html', 'index.html', 'privacy.html', 'support.html', 'terms.html']);
  for (const page of pages) assert.match(fs.readFileSync(path.join(root, 'public', page), 'utf8'), /<link rel="stylesheet" href="\/style\.css">/, page);
});
test('every class a page uses is defined in the stylesheet', () => {
  const defined = new Set([...styles.matchAll(/\.([a-zA-Z][\w-]*)/g)].map(match => match[1]));
  for (const page of pages) {
    const html = fs.readFileSync(path.join(root, 'public', page), 'utf8');
    for (const match of html.matchAll(/\sclass="([^"]+)"/g)) {
      for (const name of match[1].split(/\s+/)) assert.ok(defined.has(name), `${page}: class "${name}" has no style`);
    }
  }
});
test('every local link, image, script and font resolves to a published file', () => {
  const exists = target => {
    const clean = target.split('#')[0].split('?')[0];
    if (clean === '/' || clean === '') return true;
    if (clean.startsWith('/api/')) return true; // served by a function (firebase.json rewrites)
    const file = path.join(root, 'public', clean);
    return fs.existsSync(file) || fs.existsSync(file + '.html'); // cleanUrls
  };
  for (const page of pages) {
    const html = fs.readFileSync(path.join(root, 'public', page), 'utf8');
    for (const match of html.matchAll(/\s(?:href|src|action)="([^"]+)"/g)) {
      if (/^(https?:|mailto:|#)/.test(match[1])) continue;
      assert.ok(match[1].startsWith('/'), `${page}: ${match[1]} is not root-relative`);
      assert.ok(!match[1].startsWith('//'), `${page}: ${match[1]} leaves the site`);
      assert.ok(exists(match[1]), `${page}: ${match[1]} is not published`);
    }
  }
  for (const match of styles.matchAll(/url\("([^"]+)"\)/g)) assert.ok(exists(match[1]), `style.css: ${match[1]} is not published`);
});
test('pages speak for HolyHim 1.0 and promise nothing the app does not do', () => {
  for (const page of pages) {
    const html = fs.readFileSync(path.join(root, 'public', page), 'utf8');
    assert.doesNotMatch(html, /HolyHim 2\.0|kinder to yourself/i, page);
    assert.match(html, /<meta name="theme-color" content="#0e1217">/, page);
  }
});
