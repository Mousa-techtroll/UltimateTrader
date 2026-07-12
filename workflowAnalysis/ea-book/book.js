/* UltimateTrader Field Manual — shared book behaviours */
(function(){
  document.documentElement.classList.add('js');
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* mobile sidebar drawer */
  var sidebar = document.getElementById('sidebar');
  var menuBtn = document.getElementById('menuBtn');
  var scrim   = document.getElementById('scrim');
  function closeSide(){ if(sidebar){sidebar.classList.remove('open');} if(scrim){scrim.classList.remove('show');} }
  function openSide(){ if(sidebar){sidebar.classList.add('open');} if(scrim){scrim.classList.add('show');} }
  if(menuBtn){ menuBtn.addEventListener('click',function(){ sidebar.classList.contains('open')?closeSide():openSide(); }); }
  if(scrim){ scrim.addEventListener('click',closeSide); }
  /* close the drawer after tapping a sub-section link on mobile */
  document.querySelectorAll('.otp a, .chapters a').forEach(function(a){
    a.addEventListener('click',function(){ if(window.matchMedia('(max-width:960px)').matches) closeSide(); });
  });

  /* "On this page" scroll-spy */
  (function(){
    var toc = document.getElementById('toc');
    if(!toc || !('IntersectionObserver' in window)) return;
    var links = [].slice.call(toc.querySelectorAll('a'));
    var map = {};
    links.forEach(function(l){ var id=l.getAttribute('href'); if(id&&id.charAt(0)==='#'){ var t=document.getElementById(id.slice(1)); if(t) map[id.slice(1)]=l; } });
    var ids = Object.keys(map);
    if(!ids.length) return;
    var visible = {};
    var spy = new IntersectionObserver(function(entries){
      entries.forEach(function(en){ visible[en.target.id] = en.isIntersecting ? en.intersectionRatio : 0; });
      var best=null, bestR=0;
      ids.forEach(function(id){ if(visible[id]>bestR){ bestR=visible[id]; best=id; } });
      if(best){ links.forEach(function(l){l.classList.remove('active');}); map[best].classList.add('active'); }
    },{rootMargin:'-12% 0px -70% 0px',threshold:[0,.25,.5,1]});
    ids.forEach(function(id){ spy.observe(document.getElementById(id)); });
  })();

  /* reveal on scroll */
  (function(){
    var els = document.querySelectorAll('.reveal');
    if(reduce || !('IntersectionObserver' in window)){ els.forEach(function(e){e.classList.add('in');}); return; }
    var io = new IntersectionObserver(function(entries){
      entries.forEach(function(en){ if(en.isIntersecting){ en.target.classList.add('in'); io.unobserve(en.target);} });
    },{rootMargin:'0px 0px -8% 0px',threshold:.08});
    els.forEach(function(e){ io.observe(e); });
  })();

  /* scout filter (chapter 3 only) */
  (function(){
    var f = document.getElementById('filter');
    if(!f) return;
    var chips = f.querySelectorAll('.chip');
    var scouts = document.querySelectorAll('.scout');
    chips.forEach(function(c){
      c.addEventListener('click',function(){
        chips.forEach(function(x){x.setAttribute('aria-pressed','false');});
        c.setAttribute('aria-pressed','true');
        var key=c.dataset.f;
        scouts.forEach(function(s){ s.classList.toggle('dim', !(key==='all'||s.dataset.status===key)); });
      });
    });
  })();
})();
