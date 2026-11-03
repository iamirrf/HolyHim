(() => {
  const names=['Scripture','Meaning','Encouragement','Hope','Prayer'];
  const headings=['You Do Not Walk Alone','God in the story','For your everyday','A truth to carry','A moment of prayer'];
  let reading,index=0;
  const card=document.querySelector('#reading-card');
  const previous=document.querySelector('#previous-card'), next=document.querySelector('#next-card');
  function render(){
    if(!reading)return;
    card.dataset.index=String(index);
    document.querySelector('#sample-kind').textContent=`${names[index]} · ${index+1} of 5`;
    document.querySelector('#sample-title').textContent=headings[index];
    const body=document.querySelector('#sample-body');
    body.replaceChildren(...reading.cards[index].text.split('\n\n').map(text=>{const p=document.createElement('p');p.textContent=text;return p;}));
    body.scrollTop=0;
    document.querySelector('#sample-reference').textContent=index===0?`${reading.reference} · World English Bible`:index===4?'Original prayer · HolyHer':'';
    document.querySelector('#sample-position').textContent=`${index+1} of 5`;
    previous.disabled=index===0;
    next.replaceChildren(document.createTextNode(index===4?'Read again ':'Continue '));
    const arrow=document.createElement('span');arrow.textContent=index===4?'↺':'→';arrow.setAttribute('aria-hidden','true');next.append(arrow);
    document.querySelectorAll('[data-card]').forEach(button=>button.setAttribute('aria-pressed',String(Number(button.dataset.card)===index)));
    document.querySelectorAll('.segments i').forEach((segment,i)=>segment.classList.toggle('active',i<=index));
  }
  function move(delta){index=Math.max(0,Math.min(4,index+delta));render();}
  previous?.addEventListener('click',()=>move(-1));
  next?.addEventListener('click',()=>{if(index===4){index=0;render();}else move(1);});
  document.querySelectorAll('[data-card]').forEach(button=>button.addEventListener('click',()=>{index=Number(button.dataset.card);render();}));
  card?.addEventListener('keydown',event=>{if(event.key==='ArrowRight'){event.preventDefault();move(1);}if(event.key==='ArrowLeft'){event.preventDefault();move(-1);}});
  let touch;
  card?.addEventListener('touchstart',event=>{touch={x:event.changedTouches[0].clientX,y:event.changedTouches[0].clientY};},{passive:true});
  card?.addEventListener('touchend',event=>{if(!touch)return;const dx=event.changedTouches[0].clientX-touch.x,dy=event.changedTouches[0].clientY-touch.y;if(Math.abs(dx)>65&&Math.abs(dx)>Math.abs(dy)*1.5)move(dx<0?1:-1);touch=null;},{passive:true});
  fetch('/lesson-sample.json').then(response=>{if(!response.ok)throw Error();return response.json();}).then(value=>{reading=value;render();}).catch(()=>{previous.disabled=true;next.disabled=true;document.querySelector('#sample-position').textContent='The full sample is temporarily unavailable.';});
  const descriptions={pearl:'A soft place to begin.',rose:'Warmth for your everyday.',lavender:'A little room to exhale.',sage:'Quietly rooted.',dawn:'Mercies for a new morning.',midnight:'A stillness for the evening.'};
  const buttons=[...document.querySelectorAll('.theme-picker [data-theme]')];
  function theme(id){if(!descriptions[id])return;document.documentElement.dataset.theme=id;buttons.forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.theme===id)));document.querySelector('.theme-label').textContent=id[0].toUpperCase()+id.slice(1)+' · '+descriptions[id];}
  buttons.forEach(button=>button.addEventListener('click',()=>theme(button.dataset.theme)));
  if('IntersectionObserver' in window&&!matchMedia('(prefers-reduced-motion: reduce)').matches){document.documentElement.classList.add('js-reveals');const observer=new IntersectionObserver(entries=>{entries.forEach(entry=>{if(entry.isIntersecting){entry.target.classList.add('visible');observer.unobserve(entry.target);}});},{threshold:.08});document.querySelectorAll('.reveal').forEach(element=>observer.observe(element));}
  document.addEventListener('visibilitychange',()=>document.body.classList.toggle('page-hidden',document.hidden));
})();
