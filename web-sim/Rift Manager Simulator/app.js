// Rift Manager – Oberfläche des Simulators
const DATA = window.RIFT_DATA;
(function () {
  'use strict';
  const S = window.RiftSim;
  let TEAMS = DATA.slice();
  let CONSTS = Object.assign({}, S.DEFAULTS);
  const $ = id => document.getElementById(id);
  const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const LEAGUE_ORDER = ['LCK', 'LPL', 'LEC', 'LCS', 'CBLOL', 'LCP', 'EMEA T3'];
  const LANGN = { en: 'Englisch', ko: 'Koreanisch', zh: 'Chinesisch', de: 'Deutsch', pt: 'Portugiesisch', es: 'Spanisch', ja: 'Japanisch', vi: 'Vietnamesisch', fr: 'Französisch' };
  const state = { A: 'DTS', B: 'BYN', planA: 'Auto', planB: 'Auto', chemA: null, chemB: null, series: null, game: 0 };
  const team = sh => TEAMS.find(t => t.short === sh);
  const withOverrides = (t, side) => Object.assign({}, t, { chem: state['chem' + side] ?? t.chem });

  function leagues() { const ls = [...new Set(TEAMS.map(t => t.league))]; return ls.sort((a, b) => (LEAGUE_ORDER.indexOf(a) + 99 * (LEAGUE_ORDER.indexOf(a) < 0)) - (LEAGUE_ORDER.indexOf(b) + 99 * (LEAGUE_ORDER.indexOf(b) < 0))); }
  function teamOptions(sel) {
    return leagues().map(l => `<optgroup label="${esc(l)}">` + TEAMS.filter(t => t.league === l).sort((a, b) => S.teamOvr(b) - S.teamOvr(a)).map(t => `<option value="${esc(t.short)}"${t.short === sel ? ' selected' : ''}>${esc(t.name)} (${S.teamOvr(t).toFixed(0)})</option>`).join('') + '</optgroup>').join('');
  }
  function renderSide(side) {
    const t = team(state[side]); const el = $(side === 'A' ? 'sideA' : 'sideB');
    const chem = state['chem' + side] ?? t.chem;
    const rows = S.ROLES.map(r => {
      const p = t.players.find(x => x.role === r); const K = S.commK(p, t.lang);
      const kchip = K < 100 ? ` <span class="chip warn" title="Kommunikationswert in der Teamsprache">K ${K}</span>` : '';
      const fchip = p.f ? ' <span class="chip">Spielerin</span>' : '';
      return `<tr><td>${r}</td><td><b>${esc(p.tag)}</b>${fchip}${kchip}<div>${traitChips(p.traits)}</div></td><td class="n">${S.ovrOf(r, p.s).toFixed(0)}</td></tr>`;
    }).join('');
    const c = t.coach;
    el.innerHTML = `<div class="head"><label for="sel${side}" style="flex:1">Team ${side === 'A' ? 'Blau' : 'Rot'}<select id="sel${side}">${teamOptions(t.short)}</select></label><div class="ovr num" title="Team-OVR">${S.teamOvr(t).toFixed(1)}</div></div>
      <div class="facts"><span class="chip">${esc(t.league)}</span><span class="chip">Teamsprache ${esc(LANGN[t.lang] || t.lang)}</span><span class="chip">${c ? 'Coach ' + esc(c.name) + ' · DRA ' + c.dra + ' · TAC ' + c.tac : 'Kein Coach (Werte 30)'}</span></div>
      <div class="row" style="margin-bottom:8px"><label for="plan${side}">Jungle-Plan<select id="plan${side}">${['Auto', 'Top', 'Mid', 'Bot', 'Objectives'].map(x => `<option${state['plan' + side] === x ? ' selected' : ''}>${x}</option>`).join('')}</select></label>
      <label for="chem${side}">Chemistry <span class="num" id="chemv${side}">${chem}</span><input type="range" id="chem${side}" min="0" max="100" value="${chem}"></label></div>
      <div class="scroll"><table><thead><tr><th>Rolle</th><th>Spieler</th><th class="n">OVR</th></tr></thead><tbody>${rows}</tbody></table></div>`;
    $('sel' + side).onchange = e => { state[side] = e.target.value; state['chem' + side] = null; renderSide(side); };
    $('plan' + side).onchange = e => { state['plan' + side] = e.target.value; };
    $('chem' + side).oninput = e => { state['chem' + side] = +e.target.value; $('chemv' + side).textContent = e.target.value; };
  }

  function goldSvg(g, A, B) {
    const gold = g.gold, n = gold.length - 1; const W = 800, H = 230, L = 52, R = 12, T = 16, Bm = 28;
    const mx = Math.max(2000, ...gold.map(Math.abs)); const top = Math.ceil(mx * 1.1 / 1000) * 1000;
    const x = m => L + (W - L - R) * m / n, y = v => T + (H - T - Bm) * (top - v) / (2 * top);
    const pts = gold.map((v, m) => `${x(m).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
    const area = `M${x(0)},${y(0)} L${pts.split(' ').join(' L')} L${x(n)},${y(0)} Z`;
    let grid = ''; const step = top <= 4000 ? 1000 : top <= 10000 ? 2500 : 5000;
    const ticks = [0]; for (let v = step; v <= top; v += step) ticks.push(v, -v);
    for (const v of ticks) grid += `<line x1="${L}" x2="${W - R}" y1="${y(v)}" y2="${y(v)}" stroke="var(--line)" ${v === 0 ? 'stroke-width="1.5"' : ''}/><text x="${L - 6}" y="${y(v) + 4}" text-anchor="end" font-size="11" fill="var(--muted)">${v > 0 ? '+' : ''}${(v / 1000).toFixed(v % 1000 ? 1 : 0)}k</text>`;
    let xt = ''; for (let m = 0; m <= n; m += 5) xt += `<text x="${x(m)}" y="${H - 8}" text-anchor="middle" font-size="11" fill="var(--muted)">${m}'</text>`;
    const marks = g.log.filter(e => e.kind === 'big' || e.kind === 'obj').map(e => `<circle cx="${x(Math.min(e.min, n))}" cy="${e.side === 'A' ? T + 4 : H - Bm - 4}" r="${e.kind === 'big' ? 5 : 3}" fill="var(--${e.side === 'A' ? 'blue' : 'red'})"><title>${e.min}' ${esc(e.text)}</title></circle>`).join('');
    const last = gold[n];
    return `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Golddifferenz-Verlauf, positiv = ${esc(A.short)} vorn">
      <defs><clipPath id="cpTop"><rect x="0" y="0" width="${W}" height="${y(0)}"/></clipPath><clipPath id="cpBot"><rect x="0" y="${y(0)}" width="${W}" height="${H}"/></clipPath></defs>
      ${grid}${xt}
      <path d="${area}" fill="var(--blue-t)" clip-path="url(#cpTop)"/><path d="${area}" fill="var(--red-t)" clip-path="url(#cpBot)"/>
      <polyline points="${pts}" fill="none" stroke="var(--ink)" stroke-width="1.8"/>
      <circle cx="${x(n)}" cy="${y(last)}" r="4" fill="var(--ink)"/>
      ${marks}
      <text x="${L + 6}" y="${T + 12}" font-size="11" fill="var(--blue)">${esc(A.short)} vorn</text><text x="${L + 6}" y="${H - Bm - 6}" font-size="11" fill="var(--red)">${esc(B.short)} vorn</text>
    </svg>`;
  }

  function renderResult() {
    const sr = state.series; if (!sr) return; const A = team(sr.A), B = team(sr.B); const g = sr.res.games[state.game];
    const wn = g.winner === 'A' ? A : B;
    const kf = v => (v / 1000).toFixed(1) + 'k';
    const box = (rs, side, T) => { const tg = g.teamGold[side]; return `<h3 style="color:var(--${side === 'A' ? 'blue' : 'red'})">${esc(T.name)}</h3><table><thead><tr><th>Rolle</th><th>Spieler</th><th class="n">K/D/A</th><th class="n">KDA</th><th class="n">Gold</th><th class="n">Anteil</th><th class="n">Bewertung</th></tr></thead><tbody>${rs.map(r => `<tr><td>${r.role}</td><td>${r.tag === g.mvp ? '<span class="mvp">' + esc(r.tag) + ' · MVP</span>' : esc(r.tag)}</td><td class="n">${r.k}/${r.d}/${r.a}</td><td class="n">${r.kda.toFixed(1)}</td><td class="n">${kf(r.gold)}</td><td class="n">${Math.round(r.gold / tg * 100)} %</td><td class="n">${r.g}</td></tr>`).join('')}</tbody></table>`; };
    const vsRow = (label, a, b, fmt) => { const tot = Math.max(1, a + b); return `<div class="r"><b class="a num">${fmt(a)}</b><div class="bar" aria-label="${label}: ${fmt(a)} zu ${fmt(b)}"><i class="a" style="width:${a / tot * 100}%"></i><i class="b" style="width:${b / tot * 100}%"></i></div><b class="b num">${fmt(b)}</b><div class="lbl">${label}</div></div>`; };
    const id = v => String(v);
    $('result').innerHTML = `
      <div class="scoreboard"><div class="tn blue">${esc(A.name)}</div><div class="sc num">${sr.res.wa} : ${sr.res.wb}</div><div class="tn red">${esc(B.name)}</div></div>
      <div class="games">${sr.res.games.map((x, i) => `<button type="button" class="w-${x.winner}${i === state.game ? ' on' : ''}" data-g="${i}">Spiel ${i + 1} · ${esc((x.winner === 'A' ? A : B).short)} · ${x.dur}'</button>`).join('')}</div>
      <div class="facts">
        <span class="chip ${g.winner === 'A' ? 'blue' : 'red'}">Sieg ${esc(wn.short)} nach ${g.dur} Minuten</span>
        <span class="chip gold">MVP ${esc(g.mvp)}</span>
        <span class="chip">Comps: ${esc(A.short)} ${g.draft.A.arch} (${g.draft.A.score}) · ${esc(B.short)} ${g.draft.B.arch} (${g.draft.B.score})</span>
        <span class="chip">Jungle: ${esc(A.short)} ${g.plans.A} · ${esc(B.short)} ${g.plans.B}</span>
        <span class="chip">Gold @14: ${Math.abs(g.gold14)} Vorsprung ${esc((g.gold14 >= 0 ? A : B).short)}</span>
      </div>
      <div class="graph">${goldSvg(g, A, B)}</div>
      <div class="vs">${vsRow('Gold insgesamt', g.teamGold.A, g.teamGold.B, kf)}${vsRow('Kills', g.kills.A, g.kills.B, id)}${vsRow('Drachen', g.drakes.A, g.drakes.B, id)}</div>
      <div class="split2" style="margin-top:14px">
        <div><h3>Event-Log</h3><div class="log">${g.log.map(e => `<div class="${e.side || ''} ${e.kind}"><span class="m">${e.min}'</span><span>${esc(e.text)}</span></div>`).join('')}</div></div>
        <div class="scroll">${box(g.ratings.A, 'A', A)}<div style="height:12px"></div>${box(g.ratings.B, 'B', B)}</div>
      </div>`;
    document.querySelectorAll('.games button').forEach(b => b.onclick = () => { state.game = +b.dataset.g; renderResult(); });
  }

  function runSeries() {
    const A = withOverrides(team(state.A), 'A'), B = withOverrides(team(state.B), 'B');
    const opt = { pressure: $('pressure').checked, planA: state.planA, planB: state.planB, consts: CONSTS };
    const res = S.simulateSeries(A, B, +$('fmt').value, opt, +$('seed').value >>> 0);
    state.series = { A: state.A, B: state.B, res }; state.game = 0; renderResult();
  }

  // ---- Statistik ----
  function chunked(total, step, fn, prog, done) {
    let i = 0; const tick = () => { const end = Math.min(total, i + step); for (; i < end; i++) fn(i); prog(i / total); if (i < total) setTimeout(tick, 0); else done(); }; tick();
  }
  function runBatch() {
    const A = withOverrides(team(state.A), 'A'), B = withOverrides(team(state.B), 'B'); const N = Math.max(100, +$('nBatch').value || 2000);
    const opt = { pressure: $('pressure').checked, planA: state.planA, planB: state.planB, consts: CONSTS };
    const st = { w: 0, dur: 0, g14: 0, cb: 0, beh: 0, mvp: {}, rat: {}, kda: {}, kills: 0, gold: 0 };
    $('runBatch').disabled = true;
    chunked(N, 400, i => {
      const g = S.simulateGame(A, B, opt, (i * 2654435761 + 17) >>> 0);
      if (g.winner === 'A') st.w++; st.dur += g.dur; st.g14 += g.gold14; st.kills += g.kills.A + g.kills.B; st.gold += (g.teamGold.A + g.teamGold.B) / 2 / g.dur;
      if (g.leader14) { st.beh++; if (g.leader14 !== g.winner) st.cb++; }
      st.mvp[g.mvp] = (st.mvp[g.mvp] || 0) + 1;
      ['A', 'B'].forEach(s => g.ratings[s].forEach(r => { const k = s + '|' + r.tag; st.rat[k] = (st.rat[k] || 0) + r.g; }));
    }, f => $('pBatch').style.width = (f * 100) + '%', () => {
      $('runBatch').disabled = false; const p = st.w / N;
      const bo = (p, n) => { const need = Math.ceil(n / 2); let s = 0; const C = (a, b) => { let r = 1; for (let i = 0; i < b; i++) r = r * (a - i) / (i + 1); return r; }; for (let l = 0; l < need; l++) s += C(need - 1 + l, l) * Math.pow(p, need) * Math.pow(1 - p, l); return s; };
      const mvps = Object.entries(st.mvp).sort((a, b) => b[1] - a[1]).slice(0, 5);
      const rats = Object.entries(st.rat).map(([k, v]) => [k.split('|'), v / N]).sort((a, b) => b[1] - a[1]);
      $('batchOut').innerHTML = `<h2>${esc(A.name)} gegen ${esc(B.name)}</h2>
      <div class="tiles">
        <div class="tile"><span>Siegchance ${esc(A.short)} (Bo1)</span><b>${(p * 100).toFixed(1)} %</b></div>
        <div class="tile"><span>Siegchance ${esc(A.short)} (Bo3)</span><b>${(bo(p, 3) * 100).toFixed(1)} %</b></div>
        <div class="tile"><span>Siegchance ${esc(A.short)} (Bo5)</span><b>${(bo(p, 5) * 100).toFixed(1)} %</b></div>
        <div class="tile"><span>Spieldauer im Schnitt</span><b>${(st.dur / N).toFixed(1)}'</b></div>
        <div class="tile"><span>Gold @14 im Schnitt</span><b>${st.g14 / N >= 0 ? '+' : ''}${Math.round(st.g14 / N)}</b></div>
        <div class="tile"><span>Comebacks (Rückstand @14 gewinnt)</span><b>${(st.cb / Math.max(1, st.beh) * 100).toFixed(1)} %</b></div>
        <div class="tile"><span>Kills pro Spiel (beide Teams)</span><b>${(st.kills / N).toFixed(1)}</b></div>
        <div class="tile"><span>Gold pro Minute je Team</span><b>${Math.round(st.gold / N)}</b></div>
      </div>
      <div class="split2" style="margin-top:14px">
        <div><h3>Häufigste MVPs</h3><table><tbody>${mvps.map(([t, c]) => `<tr><td>${esc(t)}</td><td class="n">${c}</td><td class="n">${(c / N * 100).toFixed(1)} %</td></tr>`).join('')}</tbody></table></div>
        <div class="scroll"><h3>Durchschnittliche Bewertung</h3><table><tbody>${rats.map(([[s, t], v]) => `<tr><td><span class="chip ${s === 'A' ? 'blue' : 'red'}">${s === 'A' ? esc(A.short) : esc(B.short)}</span></td><td>${esc(t)}</td><td class="n">${v.toFixed(1)}</td></tr>`).join('')}</tbody></table></div>
      </div><p class="note">Bo3 und Bo5 sind aus der Bo1-Siegchance hochgerechnet. ${N} Spiele, Konstanten aus der Kalibrierung.</p>`;
    });
  }

  // ---- Kalibrierung ----
  const CDESC = { lane: ['Lane-Gold je Punkt Laning-Differenz', 'GDD: 60'], jgl: ['Gold je Punkt Jungle-Differenz', 'GDD: 50'], kill: ['Gold pro Kill', 'GDD: 300'], objDiv: ['Teiler Macro-Differenz bei Objectives', 'GDD: 10'], objGold: ['Teiler Golddifferenz bei Objectives', 'GDD: 3000'], compDiv: ['Teiler Comp-Differenz bei Objectives', 'GDD: 10'], fightDiv: ['Teiler Fight-Stärke (k)', 'GDD: 15'], fightGold: ['Fight-Bonus je 1000 Gold Vorsprung', 'GDD: 2'], throwBase: ['Throw-Grundchance', 'GDD: 0,10'], shutdown: ['Shutdown-Anteil der Golddifferenz', 'GDD: 0,15'], sigmaBase: ['Grundschwankung der Tagesform', 'GDD: 8'], mastery: ['Angenommene Champion-Mastery', 'ohne Champion-Daten'], killsPerLane: ['Kill-Events pro Lane bis Minute 14', 'GDD: 1,5'], fightKills: ['Kills des Siegers pro Teamfight im Schnitt', 'neu'], skirmish: ['Chance auf Scharmützel bei Objectives', 'vorher 0,35'], ratingBase: ['Grundwert der Spielbewertung', 'GDD: 50'], formCenter: ['Neutrale Form (FormMod 0)', 'Schnitt der Bewertungen'], gankShare: ['Grundanteil der Lane-Kills für den Jungler', 'Traits verschieben ihn'], ratingCompress: ['Stauchung der Bewertungsskala nach oben (1 = aus)', 'hebt den Boden'], formDiv: ['Formpunkte je Wertepunkt im Spiel', 'größer = schwächer'], formAmp: ['Verstärkung der Bewertung auf die Form', 'Saison'], formWeight: ['Gewicht des letzten Spiels auf die Form', 'Saison'], morale: ['Formpunkte für Serien-Sieg / -Niederlage', 'Saison'], formDrift: ['Zufällige Formdrift pro Woche', 'Saison'], chemLoss: ['Chemistry-Verlust je verlorener Serie', 'Saison'], chemWin: ['Chemistry-Gewinn je gewonnener Serie', 'Saison'], chemGrowth: ['Chemistry-Wachstum pro Woche (Basis)', 'Saison'], trainBase: ['Trainingsfortschritt pro Woche', 'Saison'], statNoise: ['Wochenschwankung der Werte', 'Saison'] };
  function renderConsts() {
    const NK = Object.keys(S.DEFAULTS).filter(k => typeof S.DEFAULTS[k] === 'number');
    $('consts').innerHTML = NK.map(k => `<label for="c_${k}">${CDESC[k][0]} <span class="note">(${CDESC[k][1]})</span><input type="number" step="any" id="c_${k}" value="${CONSTS[k]}"></label>`).join('');
    NK.forEach(k => $('c_' + k).onchange = e => { const v = parseFloat(e.target.value); if (!isNaN(v)) CONSTS[k] = v; });
  }
  const TARGET = { 0: [50, 50], 3: [58, 65], 5: [65, 77], 10: [80, 94], 15: [90, 99] };
  function synth(base, name) { return { short: name, name, lang: 'xx', chem: 60, coach: { name: 'Test', dra: 60, dev: 60, mot: 60, tac: 60, man: 60 }, players: S.ROLES.map(r => ({ tag: name + ' ' + r, role: r, langs: ['xx'], en: 50, s: [base, base, base, base, base], cha: 50, traits: [] })) }; }
  function runCal() {
    const N = Math.max(500, +$('nCal').value || 3000); const ds = [0, 3, 5, 10, 15]; const rows = []; let di = 0;
    $('runCal').disabled = true;
    const next = () => {
      if (di >= ds.length) {
        const A = synth(75, 'Team A'), B = synth(75, 'Team B'); const b = {}; const M = N * 4;
        chunked(M, 1000, i => { const g = S.simulateGame(A, B, { consts: CONSTS }, (i * 3266489917 + 5) >>> 0); const gd = g.gold[Math.min(14, g.gold.length - 1)]; const k = Math.min(7, Math.floor(Math.abs(gd) / 1000)); b[k] = b[k] || [0, 0]; b[k][0]++; if ((gd > 0 && g.winner === 'B') || (gd < 0 && g.winner === 'A')) b[k][1]++; },
          f => $('pCal').style.width = (100) + '%', () => { $('runCal').disabled = false; renderCal(rows, N, b, M); });
        return;
      }
      const d = ds[di]; const A = synth(70 + d, 'Favorit'), B = synth(70, 'Außenseiter'); const st = { w: 0, dur: 0, cb: 0, beh: 0 };
      chunked(N, 500, i => { const g = S.simulateGame(A, B, { consts: CONSTS }, (i * 2246822519 + d * 97 + 1) >>> 0); if (g.winner === 'A') st.w++; st.dur += g.dur; if (g.leader14) { st.beh++; if (g.leader14 !== g.winner) st.cb++; } },
        f => $('pCal').style.width = ((di + f) / ds.length * 100) + '%',
        () => { rows.push({ d, p: st.w / N, dur: st.dur / N, cb: st.cb / Math.max(1, st.beh) }); di++; next(); });
    }; next();
  }
  const CB_TARGET = { 4: 30, 5: 25, 6: 20, 7: 15 };
  function renderCal(rows, N, b, M) {
    const bo5 = p => { let s = 0; const C = (a, b) => { let r = 1; for (let i = 0; i < b; i++) r = r * (a - i) / (i + 1); return r; }; for (let l = 0; l < 3; l++) s += C(2 + l, l) * Math.pow(p, 3) * Math.pow(1 - p, l); return s; };
    const mark = (v, t) => `<span class="${Math.abs(v - t) <= 3 ? 'ok' : 'off'}">${v.toFixed(1)} %</span>`;
    $('calOut').innerHTML = `<h2>Ergebnis</h2><div class="scroll"><table><thead><tr><th>OVR-Differenz</th><th class="n">Bo1 simuliert</th><th class="n">Ziel Bo1</th><th class="n">Bo5 (hochgerechnet)</th><th class="n">Ziel Bo5</th><th class="n">Spieldauer</th><th class="n">Comebacks</th></tr></thead><tbody>${rows.map(r => `<tr><td class="n" style="text-align:left">${r.d}</td><td class="n">${mark(r.p * 100, TARGET[r.d][0])}</td><td class="n">${TARGET[r.d][0]} %</td><td class="n">${mark(bo5(r.p) * 100, TARGET[r.d][1])}</td><td class="n">${TARGET[r.d][1]} %</td><td class="n">${r.dur.toFixed(1)}'</td><td class="n">${(r.cb * 100).toFixed(1)} %</td></tr>`).join('')}</tbody></table></div>
    <p class="note">Grün liegt höchstens 3 Prozentpunkte vom Ziel entfernt. Ziel Spieldauer: 30–34 Minuten. ${N} Spiele pro Zeile.</p>
    <h2 style="margin-top:18px">Comebacks nach Rückstand</h2>
    <p class="lead">Zwei gleich starke Teams. Wie oft gewinnt das Team, das nach dem Laning (Minute 14) mit so viel Gold hinten liegt? ${M} Spiele.</p>
    <div class="scroll"><table><thead><tr><th>Rückstand @14</th><th class="n">Spiele</th><th class="n">Comeback simuliert</th><th class="n">Ziel</th></tr></thead><tbody>${Object.keys(b).sort((x, y) => x - y).map(k => { const [n, c] = b[k]; const p = c / n * 100; const t = CB_TARGET[k]; return `<tr><td>${k === '7' ? 'ab 7000' : k * 1000 + '–' + ((+k + 1) * 1000 - 1)}</td><td class="n">${n}</td><td class="n">${t != null && n >= 50 ? mark(p, t) : p.toFixed(1) + ' %'}</td><td class="n">${t != null ? t + ' %' : '–'}</td></tr>`; }).join('')}</tbody></table></div>
    <p class="note">Bei weniger als 50 Spielen in einer Zeile ist der Wert zu unsicher für eine Bewertung.</p>`;
  }

  // ---- Daten ----
  function renderTeams() {
    const f = $('leagueFilter').value || 'Alle';
    const list = TEAMS.filter(t => f === 'Alle' || t.league === f).sort((a, b) => S.teamOvr(b) - S.teamOvr(a));
    $('teamTable').innerHTML = `<thead><tr><th>Team</th><th>Kürzel</th><th>Liga</th><th class="n">OVR</th>${S.ROLES.map(r => `<th>${r}</th>`).join('')}</tr></thead><tbody>${list.map(t => `<tr><td>${esc(t.name)}</td><td>${esc(t.short)}</td><td>${esc(t.league)}</td><td class="n">${S.teamOvr(t).toFixed(1)}</td>${S.ROLES.map(r => { const p = t.players.find(x => x.role === r); return `<td>${esc(p.tag)} <span class="note num">${S.ovrOf(r, p.s).toFixed(0)}</span></td>`; }).join('')}</tr>`).join('')}</tbody>`;
  }
  function renderFilter() { const o = ['Alle', ...leagues()].map(l => `<option>${esc(l)}</option>`).join(''); $('leagueFilter').innerHTML = o; $('expLeague').innerHTML = o; $('leagueFilter').onchange = renderTeams; }
  function parseCSV(text) {
    const rows = []; let row = [], cur = '', q = false;
    for (let i = 0; i < text.length; i++) { const c = text[i];
      if (q) { if (c === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else q = false; } else cur += c; }
      else if (c === '"') q = true; else if (c === ',') { row.push(cur); cur = ''; } else if (c === '\n') { row.push(cur); rows.push(row); row = []; cur = ''; } else if (c !== '\r') cur += c; }
    if (cur || row.length) { row.push(cur); rows.push(row); }
    const head = rows.shift().map(h => h.trim()); return rows.filter(r => r.length > 1).map(r => Object.fromEntries(head.map((h, i) => [h, (r[i] || '').trim()])));
  }
  const ROLEMAP = { TOP: 'Top', JGL: 'Jungle', MID: 'Mid', ADC: 'ADC', SUP: 'Support' };
  const ROLECODE = { Top: 'TOP', Jungle: 'JGL', Mid: 'MID', ADC: 'ADC', Support: 'SUP' };
  // ---- Export: dieselben Spalten, die der Import liest ----
  const csvCell = v => { const x = v == null ? '' : String(v); return /[",\n]/.test(x) ? '"' + x.replace(/"/g, '""') + '"' : x; };
  const csv = rows => rows.map(r => r.map(csvCell).join(',')).join('\n') + '\n';
  function exportList() { const f = $('expLeague').value; return TEAMS.filter(t => f === 'Alle' || t.league === f); }
  function download(name, text) { const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['\ufeff' + text], { type: 'text/csv;charset=utf-8' })); a.download = name; document.body.appendChild(a); a.click(); setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 500); }
  function teamsCSV(list) {
    const head = ['short', 'name', 'league', 'tier', 'team_language', 'chem', 'coach_name', 'coach_dra', 'coach_dev', 'coach_mot', 'coach_tac', 'coach_man', 'ovr_avg'];
    return csv([head, ...list.map(t => { const c = t.coach || {}; return [t.short, t.name, t.league, t.tier || 1, t.lang, t.chem, c.name || '', c.dra ?? '', c.dev ?? '', c.mot ?? '', c.tac ?? '', c.man ?? '', S.teamOvr(t).toFixed(1)]; })]);
  }
  function playersCSV(list) {
    const head = ['team_short', 'name', 'nickname', 'role', 'age', 'gender', 'language', 'english', 'mechanics', 'laning', 'macro', 'teamwork', 'mental', 'charisma', 'potential', 'ovr', 'traits'];
    const rows = [head]; list.forEach(t => t.players.forEach(p => rows.push([t.short, p.real || '', p.tag, ROLECODE[p.role], p.age, p.f ? 'f' : 'm', p.langs.join(';'), Math.round(p.en), ...p.s.map(x => Math.round(x)), p.cha, p.pot ?? '', S.ovrOf(p.role, p.s).toFixed(1), p.traits.join(';')])));
    return csv(rows);
  }
  function doExport(kind) {
    const list = exportList(); const tag = $('expLeague').value === 'Alle' ? 'alle' : $('expLeague').value.toLowerCase();
    if (kind === 'teams') download(`rift_teams_${tag}.csv`, teamsCSV(list)); else download(`rift_players_${tag}.csv`, playersCSV(list));
    $('expMsg').textContent = `${list.length} Teams mit ${list.length * 5} Spielern exportiert.`;
  }
  async function doImport() {
    const ft = $('fTeams').files[0], fp = $('fPlayers').files[0];
    if (!ft || !fp) { $('importMsg').textContent = 'Bitte beide Dateien auswählen: teams.csv und players.csv.'; return; }
    try {
      const ts = parseCSV(await ft.text()), ps = parseCSV(await fp.text()); let added = 0, skipped = [];
      ts.forEach(t => {
        const pl = ps.filter(p => p.team_short === t.short);
        const players = S.ROLES.map(r => { const p = pl.find(x => ROLEMAP[(x.role || '').toUpperCase()] === r); if (!p) return null;
          const num = k => Math.max(0, Math.min(100, parseFloat(p[k]) || 50));
          return { tag: p.nickname || p.name, real: p.name, role: r, age: +p.age || 20, langs: (p.language || 'en').split(';'), en: p.english ? num('english') : 60, s: ['mechanics', 'laning', 'macro', 'teamwork', 'mental'].map(num), cha: num('charisma'), traits: (p.traits || '').split(';').map(x => x.trim()).filter(Boolean), f: p.gender === 'f', pot: p.potential ? num('potential') : null }; });
        if (players.some(x => !x)) { skipped.push(t.short); return; }
        const cv = k => Math.max(0, Math.min(100, parseFloat(t['coach_' + k]) || 60));
        const coach = 'coach_name' in t ? (t.coach_name ? { name: t.coach_name, dra: cv('dra'), dev: cv('dev'), mot: cv('mot'), tac: cv('tac'), man: cv('man') } : null) : { name: 'Generator-Coach', dra: 60, dev: 60, mot: 60, tac: 60, man: 60 };
        players.forEach(p => { if (p.pot == null) p.pot = Math.min(99, Math.round(S.ovrOf(p.role, p.s)) + 5); });
        const obj = { short: t.short, name: t.name || t.short, league: t.league || 'Import', tier: +t.tier || 1, lang: t.team_language || 'en', chem: t.chem ? Math.max(0, Math.min(100, +t.chem)) : 60, coach, players };
        const i = TEAMS.findIndex(x => x.short === obj.short); if (i >= 0) TEAMS[i] = obj; else TEAMS.push(obj); added++;
      });
      $('importMsg').textContent = `${added} Teams geladen.` + (skipped.length ? ` Übersprungen, weil eine Rolle fehlt: ${skipped.join(', ')}.` : '');
      renderFilter(); renderTeams(); renderSide('A'); renderSide('B');
    } catch (e) { $('importMsg').textContent = 'Die Dateien konnten nicht gelesen werden. Prüfe, ob es CSV mit Komma als Trennzeichen ist. (' + e.message + ')'; }
  }

  // ---- Saison ----
  const Z = window.RiftSeason; let SEA = null, selTeam = null, viewWeek = null, selPlayer = null;
  const TRAITS = {
    'Lane Bully': ['+', '+5 Laning in der Lane-Phase. Holt seine Lane-Kills lieber selbst, der Jungler bekommt seltener den Kill.'],
    'Early-Game-Spezialist': ['+', '+4 Mechanics und Laning bis Minute 14. Als Jungler hilft er häufiger bei Kills.'],
    'Late-Game-Monster': ['+', '+4 Mechanics in Teamfights ab Minute 35.'],
    'Carry': ['+', '+4 Mechanics in Teamfights, solange das Team vorne liegt. Nimmt Lane-Kills lieber selbst.'],
    'Teamplayer': ['+', 'Chemistry wächst mit ihm 30 % schneller. Überlässt dem Jungler öfter den Kill.'],
    'Shotcaller': ['+', 'Hebt die Macro-Entscheidungen des Teams bei Objectives.'],
    'Engage Caller': ['+', '+3 Teamfight-Stärke für das ganze Team.'],
    'Vision Master': ['+', '+3 auf die Objective-Kontrolle des Teams.'],
    'Clutch Player': ['+', 'In Playoffs und Entscheidungsspielen +5 Mechanics und nur halb so große Schwankung.'],
    'Bühnentier': ['+', 'Unter Druck (Playoffs) +3 Mechanics.'],
    'Tilt-Proof': ['+', 'Schwankt von Spiel zu Spiel 25 % weniger.'],
    'Risikoarm': ['+', 'Wird 30 % seltener erwischt, wenn ein Kill fällt.'],
    'Invader': ['+', 'Jungler: +3 Jungle-Druck, stärker auf der Fokus-Lane, holt mehr Kills selbst.'],
    'Roamer': ['+', 'Mid oder Support hilft zusätzlich auf der schwächsten anderen Lane.'],
    'Weak-Side-Spezialist': ['+', 'Leidet weniger, wenn der Jungler die andere Seite spielt.'],
    'Mentor': ['+', 'Ab 24 Jahren: Spieler bis 21 im Team trainieren 15 % schneller.'],
    'Grinder': ['+', 'Trainiert 10 % schneller.'],
    'Perfektionist': ['+', 'Trainiert 15 % schneller.'],
    'Late Bloomer': ['+', 'Entwickelt sich bis 25 so schnell wie ein 22-Jähriger.'],
    'Sprachtalent': ['+', 'Lernt Englisch doppelt so schnell.'],
    'Fan Favorite': ['·', 'Beliebt bei den Fans. Wirkt später auf Sponsoren und Reputation, im Prototyp noch ohne Wirkung.'],
    'Medienprofi': ['·', 'Souverän vor Kamera und Presse. Im Prototyp noch ohne Wirkung.'],
    'Champion Ocean': ['·', 'Riesiger Champion-Pool. Wirkt mit Champion-Daten auf den Draft, im Prototyp noch ohne Wirkung.'],
    'Meta-Chaser': ['·', 'Passt sich schnell an Patches an. Wirkt mit Patches, im Prototyp noch ohne Wirkung.'],
    'Meta-Macher': ['·', 'Erfindet eigene Picks und Strategien. Im Prototyp noch ohne Wirkung.'],
    'Ironman': ['·', 'Kaum Burnout-Gefahr. Wirkt mit Burnout, im Prototyp noch ohne Wirkung.'],
    'Arrogant': ['±', '+3 Mental, aber Chemistry wächst 20 % langsamer.'],
    'Egoist': ['±', '+3 Mechanics, −4 Teamwork. Nimmt Lane-Kills lieber selbst.'],
    'Hot-Headed': ['−', 'Schwankt von Spiel zu Spiel 50 % stärker.'],
    'Choker': ['−', 'In Playoffs und Entscheidungsspielen −5 Mental.'],
    'Bühnenangst': ['−', 'Unter Druck (Playoffs) −4 Mechanics.'],
    'Lone Wolf': ['−', 'Chemistry wächst mit ihm nur halb so schnell.'],
    'Faul': ['−', 'Trainiert 20 % langsamer.'],
    'One-Trick': ['−', 'Kleiner Champion-Pool. Wirkt mit Champion-Daten im Draft, im Prototyp noch ohne Wirkung.']
  };
  function traitChips(list) {
    if (!list.length) return '<span class="note">keine Traits</span>';
    return list.map(t => { const d = TRAITS[t] || ['·', 'Noch keine Beschreibung.']; const cls = d[0] === '+' ? 'pos' : d[0] === '−' ? 'neg' : ''; return `<span class="tr ${cls}" tabindex="0">${esc(t)}<span class="tip" role="tooltip"><b>${esc(t)}</b>${esc(d[1])}</span></span>`; }).join('');
  }
  function fmtOptions() {
    const lg = $('sLeague').value; const list = Z.PRESETS[lg] || Z.PRESETS.LEC.slice(0, 1);
    $('sFmt').innerHTML = list.map(p => `<option value="${p.id}|${p.bestOf}">${esc(p.name)}</option>`).join('');
  }
  function curPreset() { const lg = SEA ? SEA.lg : $('sLeague').value; const list = Z.PRESETS[lg] || Z.PRESETS.LEC.slice(0, 1); return list.find(p => p.id === SEA.opt.preset) || list[0]; }
  function seasonLeagues() { return leagues().filter(l => TEAMS.filter(t => t.league === l).length >= 6); }
  function newSeason() {
    const lg = $('sLeague').value; const [preset, bo] = $('sFmt').value.split('|');
    SEA = Z.create(TEAMS.filter(t => t.league === lg), { seed: +$('sSeed').value >>> 0, preset, bestOf: +bo, consts: CONSTS }); SEA.lg = lg;
    selTeam = Z.standings(SEA)[0].short; selPlayer = null; viewWeek = null; renderSeason();
  }
  const delta = (v, d = 1) => { const x = +v.toFixed(d); return `<span class="delta ${x > 0 ? 'up' : x < 0 ? 'down' : ''}">${x > 0 ? '+' : ''}${x.toFixed(d)}</span>`; };
  function renderSeason() {
    if (!SEA) return;
    const W = Z.totalWeeks(SEA), tab = Z.standings(SEA), bo3 = SEA.opt.bestOf > 1, rd = Z.regularDone(SEA), pr = curPreset();
    $('sFmtNote').textContent = pr.note;
    const phase = SEA.opt.preset === 'lck' ? (SEA.phase === 2 ? ' · Runden 3–4' : ' · Runden 1–2') : '';
    $('sHead').innerHTML = `<div class="row" style="justify-content:space-between;margin-bottom:8px"><div class="wk">${esc(SEA.lg)} · Woche ${SEA.week} von ${W}${phase}${SEA.done ? ' · abgeschlossen' : rd ? ' · Playoffs stehen an' : ''}</div><span class="chip">${esc(pr.name)}</span></div>`;
    const cols = bo3 ? 9 : 8;
    $('sTable').innerHTML = `<thead><tr><th class="n">#</th><th>Team</th><th class="n">S</th><th class="n">N</th>${bo3 ? '<th class="n">Maps</th>' : ''}<th>Letzte 5</th><th class="n">Form Ø</th><th class="n">Chemistry</th><th class="n">OVR</th></tr></thead><tbody>${tab.map((t, i) => {
      const form = t.players.reduce((a, p) => a + p.form, 0) / 5; const ovr = S.teamOvr(t); const ovr0 = t.players.reduce((a, p) => a + p.start.ovr, 0) / 5;
      const gh = t.group && (i === 0 || tab[i - 1].group !== t.group) ? `<tr class="grp"><td colspan="${cols}">${esc(t.group)} Group</td></tr>` : '';
      return gh + `<tr class="click${t.short === selTeam ? ' sel' : ''}${i === 5 ? ' cut' : ''}" data-t="${esc(t.short)}"><td class="n">${i + 1}</td><td><b>${esc(t.name)}</b></td><td class="n">${t.rec.w}</td><td class="n">${t.rec.l}</td>${bo3 ? `<td class="n">${t.rec.mw}:${t.rec.ml}</td>` : ''}<td><span class="form5">${t.rec.last.slice(-5).map(x => `<i class="${x}">${x}</i>`).join('')}</span></td><td class="n">${form.toFixed(0)}</td><td class="n">${t.chem.toFixed(0)} ${delta(t.chem - t.chemStart, 0)}</td><td class="n">${ovr.toFixed(1)} ${delta(ovr - ovr0)}</td></tr>`; }).join('')}</tbody>`;
    document.querySelectorAll('#sTable tr.click').forEach(r => r.onclick = () => { selTeam = r.dataset.t; selPlayer = null; renderSeason(); });
    // Spieltage
    const wi = viewWeek ?? SEA.results.length - 1;
    if (SEA.results.length === 0) {
      const nxt = SEA.weeks[0].flat();
      $('sWeekBox').innerHTML = `<h3>Woche 1: Spielplan</h3><div class="res">${nxt.map(([a, b]) => `<button type="button" disabled><span>${esc(Z.team(SEA, a).name)}</span><span class="sc">–</span><span>${esc(Z.team(SEA, b).name)}</span></button>`).join('')}</div>`;
    } else {
      const wk = SEA.results[wi];
      $('sWeekBox').innerHTML = `<div class="row" style="justify-content:space-between"><h3>Woche ${wk.n}: Ergebnisse</h3><label for="sWk">Woche<select id="sWk">${SEA.results.map((r, i) => `<option value="${i}"${i === wi ? ' selected' : ''}>${r.n}</option>`).join('')}</select></label></div>${wk.days.map((d, di) => `<p class="note" style="margin:8px 0 4px">Spieltag ${(wk.n - 1) * 2 + di + 1}${wk.phase === 2 ? ' · Legend und Rise Group' : ''}</p><div class="res">${d.map((r, ri) => `<button type="button" data-w="${wi}" data-d="${di}" data-r="${ri}" title="Im Match ansehen"><span class="${r.winner === r.a ? 'w' : ''}">${esc(Z.team(SEA, r.a).name)}</span><span class="sc num">${r.wa}:${r.wb}</span><span class="${r.winner === r.b ? 'w' : ''}">${esc(Z.team(SEA, r.b).name)}</span></button>`).join('')}</div>`).join('')}<p class="note">Klick auf ein Ergebnis öffnet die Serie in der Match-Ansicht.</p>`;
      $('sWk').onchange = e => { viewWeek = +e.target.value; renderSeason(); };
      document.querySelectorAll('#sWeekBox .res button[data-w]').forEach(b => b.onclick = () => openSeries(SEA.results[+b.dataset.w].days[+b.dataset.d][+b.dataset.r]));
    }
    // Kader
    const T = Z.team(SEA, selTeam);
    $('sTeamBox').innerHTML = `<h3>${esc(T.name)}: Kader</h3><div class="scroll"><table><thead><tr><th>Rolle</th><th>Spieler</th><th class="n">OVR</th><th class="n">Form</th><th class="n">Spiele</th><th class="n">Ø Bew.</th><th class="n">K/D/A</th><th class="n">MVP</th></tr></thead><tbody>${T.players.map(p => { const o = S.ovrOf(p.role, p.s); return `<tr class="pl${p.tag === selPlayer ? ' on' : ''}" data-p="${esc(p.tag)}" tabindex="0"><td>${p.role}</td><td><b>${esc(p.tag)}</b> <span class="note">${p.age} J.</span></td><td class="n">${o.toFixed(1)} ${delta(o - p.start.ovr)}</td><td class="n">${p.form.toFixed(0)}</td><td class="n">${p.games}</td><td class="n">${p.games ? (p.sumG / p.games).toFixed(1) : '–'}</td><td class="n">${p.k}/${p.d}/${p.a}</td><td class="n">${p.mvps}</td></tr>`; }).join('')}</tbody></table></div>
      <p class="note">Coach: ${T.coach ? esc(T.coach.name) + ' (DEV ' + T.coach.dev + ', MAN ' + T.coach.man + ', MOT ' + T.coach.mot + ')' : 'keiner'}. Klick auf einen Spieler zeigt Werte, Verlauf und Traits.</p>`;
    document.querySelectorAll('#sTeamBox tr.pl').forEach(r => { const go = () => { selPlayer = r.dataset.p; renderSeason(); $('sPlayerBox').scrollIntoView({ behavior: 'smooth', block: 'nearest' }); }; r.onclick = go; r.onkeydown = e => { if (e.key === 'Enter') go(); }; });
    renderPlayer(T);
    // Playoffs + Awards
    if (!SEA.playoffs) { $('sPOBox').innerHTML = `<h3>Playoffs</h3><p class="note">Nach der regulären Saison spielen die Top 6 im Bo5: Platz 3 gegen 6 und 4 gegen 5 im Viertelfinale, Platz 1 und 2 steigen im Halbfinale ein.${SEA.opt.preset === 'lck' ? ' In der LCK sind das die Legend Group und der Erste der Rise Group.' : SEA.opt.preset === 'lpl' ? ' In der LPL kommen alle sechs aus der Ascend Group.' : ''}</p>`; }
    else {
      const P = SEA.playoffs, aw = Z.awards(SEA);
      const ser = s => `<button type="button" class="po" data-po="${P.rounds.findIndex(r => r.series.includes(s))}|${P.rounds.find(r => r.series.includes(s)).series.indexOf(s)}" style="width:100%;margin-bottom:6px"><span class="${s.winner === s.a ? 'w' : ''}">${esc(Z.team(SEA, s.a).name)}</span> <span class="sc num">${s.wa}:${s.wb}</span> <span class="${s.winner === s.b ? 'w' : ''}">${esc(Z.team(SEA, s.b).name)}</span></button>`;
      const pl = x => x ? `${esc(x.p.tag)} <span class="note">(${esc(x.T.short)}, Ø ${aw.avg(x).toFixed(1)})</span>` : '–';
      $('sPOBox').innerHTML = `<div class="row" style="justify-content:space-between"><h3>Playoffs</h3><div class="champ">Meister: ${esc(Z.team(SEA, P.champion).name)}</div></div>
        <div class="bracket res">${P.rounds.map(r => `<div><p class="note" style="margin:0 0 6px">${r.name}</p>${r.series.map(ser).join('')}</div>`).join('')}</div>
        <h3 style="margin-top:16px">Auszeichnungen</h3>
        <table><tbody><tr><td>Split-MVP</td><td>${pl(aw.mvp)} · ${aw.mvp.p.mvps} MVP-Titel</td></tr>
        <tr><td>All-Pro-Team</td><td>${aw.allPro.map(x => `${x.p.role}: ${pl(x)}`).join('<br>')}</td></tr>
        <tr><td>Rookie des Splits</td><td>${pl(aw.rookie)}</td></tr>
        <tr><td>Größte Steigerung</td><td>${esc(aw.improved.x.p.tag)} <span class="note">(${esc(aw.improved.x.T.short)}, OVR ${delta(aw.improved.d)})</span></td></tr></tbody></table>`;
      document.querySelectorAll('#sPOBox button.po').forEach(b => b.onclick = () => { const [ri, si] = b.dataset.po.split('|').map(Number); openSeries(P.rounds[ri].series[si]); });
    }
    $('sWeek').disabled = rd; $('sAll').disabled = rd; $('sPO').disabled = !rd || SEA.done;
  }
  function spark(vals, lo, hi, ref, label) {
    if (vals.length < 2) return '<p class="note">Noch keine Daten.</p>';
    const w = 300, h = 70, x = i => 4 + i * (w - 8) / (vals.length - 1), y = v => h - 4 - (Math.max(lo, Math.min(hi, v)) - lo) / (hi - lo) * (h - 8);
    const pts = vals.map((v, i) => `${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
    return `<svg class="spark" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" role="img" aria-label="${label}"><line x1="0" x2="${w}" y1="${y(ref)}" y2="${y(ref)}" stroke="var(--line)" stroke-dasharray="4 4"/><polyline points="${pts}" fill="none" stroke="var(--gold)" stroke-width="2" vector-effect="non-scaling-stroke"/></svg>`;
  }
  function renderPlayer(T) {
    const box = $('sPlayerBox'); const p = T.players.find(x => x.tag === selPlayer);
    if (!p) { box.hidden = true; return; }
    box.hidden = false;
    const NAMES = ['Mechanics', 'Laning', 'Macro', 'Teamwork', 'Mental'];
    const o = S.ovrOf(p.role, p.s), C = Object.assign({}, S.DEFAULTS, CONSTS);
    const fm = Math.max(-4, Math.min(4, (p.form - C.formCenter) / C.formDiv));
    const kda = (p.k + p.a) / Math.max(1, p.d);
    const stats = p.s.map((v, i) => `<div class="sbar"><span>${NAMES[i]}${S.W[p.role][i] >= 0.25 ? ' <span class="note">★</span>' : ''}</span><span class="bar"><i style="width:${v}%"></i><b style="left:${p.start.s[i]}%"></b></span><span class="num">${v.toFixed(1)} ${delta(v - p.start.s[i])}</span></div>`).join('');
    const formLine = p.hist.map(h => h.form), ovrLine = p.hist.map(h => h.ovr);
    box.innerHTML = `<div class="row" style="justify-content:space-between;align-items:baseline"><h3>${esc(p.tag)} <span class="note" style="text-transform:none;letter-spacing:0">${esc(p.real || '')} · ${p.role} · ${p.age} J. · ${esc(T.name)}</span></h3><button type="button" id="pClose">Schließen</button></div>
      <div class="pgrid">
        <div><p class="note" style="margin:0 0 6px">Werte jetzt, Strich = Saisonstart, ★ = wichtig für die Rolle</p>${stats}
          <div class="sbar"><span><b>OVR</b></span><span class="bar"><i style="width:${o}%"></i><b style="left:${p.start.ovr}%"></b></span><span class="num"><b>${o.toFixed(1)}</b> ${delta(o - p.start.ovr)}</span></div>
          <p class="note">Sprachen: ${esc(p.langs.join(', '))} · Englisch ${Math.round(p.en)}</p></div>
        <div><p class="note" style="margin:0 0 4px">Form ${p.form.toFixed(0)} · wirkt mit ${fm >= 0 ? '+' : ''}${fm.toFixed(1)} auf alle Werte im Spiel</p>${spark(formLine, 25, 99, C.formCenter, 'Formverlauf')}
          <p class="note" style="margin:10px 0 4px">OVR-Verlauf je Woche</p>${spark(ovrLine, Math.min(...ovrLine) - 1, Math.max(...ovrLine) + 1, p.start.ovr, 'OVR-Verlauf')}</div>
        <div><p class="note" style="margin:0 0 4px">Bewertung je Spiel · Ø ${p.games ? (p.sumG / p.games).toFixed(1) : '–'}</p>${spark(p.gr, 30, 100, 70, 'Bewertungen')}
          <table style="margin-top:8px"><tbody><tr><td>Spiele</td><td class="n">${p.games}</td></tr><tr><td>K/D/A</td><td class="n">${p.k}/${p.d}/${p.a} · KDA ${kda.toFixed(1)}</td></tr><tr><td>Gold je Spiel</td><td class="n">${p.games ? Math.round(p.gold / p.games).toLocaleString('de-DE') : '–'}</td></tr><tr><td>MVP-Titel</td><td class="n">${p.mvps}</td></tr></tbody></table></div>
      </div>
      <p class="note" style="margin:12px 0 4px">Traits (Maus drüber oder antippen für die Wirkung)</p><div>${traitChips(p.traits)}</div>`;
    $('pClose').onclick = () => { selPlayer = null; renderSeason(); };
  }
  function openSeries(r) {
    state.A = r.a; state.B = r.b; state.chemA = null; state.chemB = null;
    state.series = { A: r.a, B: r.b, res: { games: r.games, wa: r.wa, wb: r.wb } }; state.game = 0;
    renderSide('A'); renderSide('B'); renderResult(); location.hash = '#match';
  }
  $('sLeague').innerHTML = seasonLeagues().map(l => `<option>${esc(l)}</option>`).join(''); fmtOptions();
  $('sLeague').onchange = fmtOptions;
  $('sNew').onclick = newSeason;
  $('sWeek').onclick = () => { Z.playWeek(SEA); viewWeek = null; renderSeason(); };
  $('sAll').onclick = () => { while (Z.playWeek(SEA)); viewWeek = null; renderSeason(); };
  $('sPO').onclick = () => { Z.startPlayoffs(SEA); renderSeason(); };

  // ---- Routing ----
  const VIEWS = ['match', 'saison', 'statistik', 'kalibrierung', 'daten'];
  function route() { const v = VIEWS.includes(location.hash.slice(1)) ? location.hash.slice(1) : 'match'; VIEWS.forEach(x => { $('view-' + x).classList.toggle('on', x === v); $('nav-' + x).classList.toggle('on', x === v); }); }
  window.addEventListener('hashchange', route);

  $('run').onclick = runSeries; $('reseed').onclick = () => { $('seed').value = Math.floor(Math.random() * 1e6); runSeries(); };
  $('fmt').onchange = () => { $('run').textContent = $('fmt').value === '1' ? 'Spiel simulieren' : 'Serie simulieren'; };
  $('runBatch').onclick = runBatch; $('runCal').onclick = runCal;
  $('resetConsts').onclick = () => { CONSTS = Object.assign({}, S.DEFAULTS); renderConsts(); };
  $('importBtn').onclick = doImport; $('expTeams').onclick = () => doExport('teams'); $('expPlayers').onclick = () => doExport('players');
  renderSide('A'); renderSide('B'); renderConsts(); renderFilter(); renderTeams(); route(); runSeries(); newSeason();
  $('batchOut').innerHTML = '<p class="note">Wähle die Teams in der Match-Ansicht und starte die Berechnung.</p>';
  $('calOut').innerHTML = '<p class="note">Startet mit den Standardwerten. Erwartung mit den aktuellen Konstanten: bei 5 Punkten Differenz rund 67 % Bo1, bei 4000 Gold Rückstand rund 30 % Comebacks.</p>';
})();
