/* ============================================================
   bitirim_hud — app.js
   Sadece veri değişince DOM güncellenir. requestAnimationFrame yok,
   sürekli döngü yok; her şey gelen mesajla tetiklenir (FPS dostu).
   ============================================================ */
(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const nf = new Intl.NumberFormat('tr-TR');

  // Eşikler (config'ten güncellenir)
  let fuelLow = 15, engLow = 30;

  // Para fade için son değerler
  let shownCash = null, shownBank = null;

  const pad2 = (n) => String(n).padStart(2, '0');

  const setMoney = (el, value, prev) => {
    el.textContent = nf.format(value);
    if (prev !== null && prev !== value) {
      el.classList.remove('fade'); void el.offsetWidth; el.classList.add('fade');
    }
  };

  // Hız sayısı için kısa ölçek darbesi
  let bumpT;
  const bump = (el) => { el.classList.add('bump'); clearTimeout(bumpT); bumpT = setTimeout(() => el.classList.remove('bump'), 150); };

  // Segment aralıkları (KM/H)
  const SEG_RANGES = [[0,100],[100,200],[200,300],[300,400]];
  const SEG_COLORS = ['#f4f6fb','#4fd08a','#f2c94c','#eb5757'];

  window.addEventListener('message', (ev) => {
    const { action, data } = ev.data || {};
    if (!action) return;

    // Bitirim: global show/hide, used by bitirim_spawn during the spawn screen.
    if (action === 'visible') {
      document.getElementById('hud').classList.toggle('hidden', data && data.visible === false);
      return;
    }

    // ---------------- config: görünürlük + eşikler ----------------
    if (action === 'config') {
      fuelLow = data.fuelLow ?? fuelLow;
      engLow  = data.engLow ?? engLow;

      // Bölüm görünürlüğü
      const g = data.groups || {};
      if (g.status === false)  $('status').style.display = 'none';
      if (g.street === false)  $('street').style.display = 'none';
      if (g.vehicle === false) $('vehicle').style.display = 'none';
      if (g.money === false) document.querySelectorAll('[data-group="money"]').forEach((e) => e.style.display = 'none');
      if (g.info === false)  document.querySelectorAll('[data-group="info"]').forEach((e) => e.style.display = 'none');

      // Araç ikon görünürlüğü
      const v = data.show || {};
      const map = { seatbelt:'tgBelt', engine:'tgEngine', lock:'tgLock', cruise:'tgCruise', fuel:'mtFuel', health:'mtHealth' };
      for (const key in map) {
        if (v[key] === false) { const el = $(map[key]); if (el) el.style.display = 'none'; }
      }

      $('speedUnit').textContent = data.unit === 'mph' ? 'MPH' : 'KM/H';
      return;
    }

    // ---------------- durum: can / zırh / yemek / su ----------------
    if (action === 'status') {
      $('status').classList.remove('hidden');
      $('healthPct').textContent = data.health + '%';
      $('armorPct').textContent  = data.armor + '%';
      $('hungerPct').textContent = data.hunger + '%';
      $('thirstPct').textContent = data.thirst + '%';
      return;
    }

    // ---------------- para: bank / cash ----------------
    if (action === 'money') {
      $('cluster').classList.remove('hidden');
      setMoney($('bankVal'), data.bank, shownBank); shownBank = data.bank;
      setMoney($('cashVal'), data.cash, shownCash); shownCash = data.cash;
      return;
    }

    // ---------------- bilgi: ID + oyuncu + saat ----------------
    if (action === 'info') {
      $('cluster').classList.remove('hidden');
      $('idVal').textContent = data.id;
      $('playersVal').textContent = data.players;
      $('timeVal').textContent = pad2(data.hour) + ':' + pad2(data.minute);
      return;
    }

    // ---------------- cadde ----------------
    if (action === 'street') {
      $('street').classList.remove('hidden');
      $('streetVal').textContent = data.name;
      return;
    }

    // ---------------- araç (segmentli hız göstergesi) ----------------
    if (action === 'vehicle') {
      const veh = $('vehicle');
      if (!data.visible) { veh.classList.add('hidden'); return; }
      veh.classList.remove('hidden');

      const speed = data.speed;

      // Merkez hız + renk (aktif üst segment) + ölçek darbesi
      const sEl = $('speedVal');
      sEl.textContent = speed;
      const top = speed > 300 ? 3 : speed > 200 ? 2 : speed > 100 ? 1 : 0;
      sEl.style.color = SEG_COLORS[top];
      bump(sEl);
      $('speedUnit').textContent = data.unit === 'mph' ? 'MPH' : 'KM/H';

      // 4 segment: soldan sağa dolar (scaleX), her biri kendi aralığında
      for (let i = 0; i < 4; i++) {
        const [lo, hi] = SEG_RANGES[i];
        const f = Math.max(0, Math.min(1, (speed - lo) / (hi - lo)));
        $('seg' + i).style.transform = 'scaleX(' + f.toFixed(3) + ')';
      }

      // Toggle'lar: aktifken altın sarı (motor / kemer / kilit / cruise)
      $('tgEngine').classList.toggle('on', data.engineOn);
      $('tgBelt').classList.toggle('on', data.seatbelt);
      $('tgLock').classList.toggle('on', data.locked);
      $('tgCruise').classList.toggle('on', data.cruise);

      // Yakıt ve motor sağlığı: %25 altında kırmızı
      $('fuelVal').textContent = data.fuel + '%';
      $('mtFuel').classList.toggle('crit', data.fuel < 25);
      $('healthVal').textContent = data.health + '%';
      $('mtHealth').classList.toggle('crit', data.health < 25);
      return;
    }
  });
})();
