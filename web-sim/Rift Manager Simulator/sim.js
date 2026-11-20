// Rift Manager – Simulationskern (Prototyp). Formeln nach dem Game-Design-Dokument.
(function (G) {
  'use strict';
  const ROLES = ['Top', 'Jungle', 'Mid', 'ADC', 'Support'];
  const W = { Top: [.25, .30, .15, .10, .20], Jungle: [.20, .05, .40, .20, .15], Mid: [.30, .25, .25, .10, .10], ADC: [.35, .30, .10, .15, .10], Support: [.10, .15, .30, .35, .10] };
  const ARCH = ['Engage', 'Poke', 'Pick', 'Split', 'Scaling', 'Control', 'Teamfight'];
  // Zeitkurve je Archetyp: Minute 14–25, 25–35, ab 35
  const CURVE = { Pick: [3, 1, -1], Poke: [2, 2, 0], Engage: [1, 3, 2], Split: [1, 2, 3], Control: [0, 2, 3], Teamfight: [-1, 3, 4], Scaling: [-3, 1, 6] };
  // Counter-Matrix (Gewinner, Verlierer, Wert); antisymmetrisch
  const BEATS = [['Engage', 'Poke', 3], ['Engage', 'Split', 2], ['Scaling', 'Engage', 2], ['Control', 'Engage', 3], ['Poke', 'Scaling', 3], ['Poke', 'Control', 2], ['Pick', 'Poke', 2], ['Poke', 'Teamfight', 2], ['Pick', 'Split', 3], ['Pick', 'Scaling', 2], ['Control', 'Pick', 2], ['Teamfight', 'Pick', 3], ['Split', 'Teamfight', 3], ['Split', 'Control', 2], ['Scaling', 'Split', 2], ['Teamfight', 'Control', 2], ['Teamfight', 'Scaling', 2]];
  const M = {}; ARCH.forEach(a => { M[a] = {}; ARCH.forEach(b => M[a][b] = 0); });
  BEATS.forEach(([a, b, v]) => { M[a][b] = v; M[b][a] = -v; });

  const DEFAULTS = { lane: 50, jgl: 25, kill: 400, objDiv: 50, objGold: 3500, compDiv: 10, fightDiv: 80, fightGold: 3, throwBase: 0.10, shutdown: 0.35, sigmaBase: 8, mastery: 85, killsPerLane: 2.5, fightKills: 3.4, skirmish: 0.6, ratingBase: 60, ratingCompress: 0.7, formCenter: 71, formDiv: 12, formAmp: 1.8, formWeight: 0.3, morale: 2, formDrift: 1.5, chemLoss: 2, chemWin: 1, chemGrowth: 1.2, trainBase: 0.3, statNoise: 0.9, gankShare: 0.2, kdaBase: { Top: 4.5, Jungle: 6, Mid: 4.5, ADC: 5, Support: 5.5 } };

  function mulberry32(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
  const sig = x => 1 / (1 + Math.exp(-x));
  const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
  function ovrOf(role, s) { return W[role].reduce((acc, w, i) => acc + w * s[i], 0); }

  function makeRng(seed) {
    const r = mulberry32(seed >>> 0);
    const api = {
      r, u: () => r(),
      int: (a, b) => a + Math.floor(r() * (b - a + 1)),
      gauss: () => { let u = 0, v = 0; while (u === 0) u = r(); while (v === 0) v = r(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); },
      pick: arr => arr[Math.floor(r() * arr.length)],
      poisson: lam => { const L = Math.exp(-lam); let k = 0, p = 1; do { k++; p *= r(); } while (p > L); return k - 1; },
      weighted: (items, w) => { const tot = w.reduce((a, b) => a + b, 0); let x = r() * tot; for (let i = 0; i < items.length; i++) { x -= w[i]; if (x <= 0) return items[i]; } return items[items.length - 1]; }
    };
    return api;
  }

  // Kommunikationswert K nach GDD
  function commK(p, teamLang) {
    if (p.langs.includes(teamLang)) return 100;
    if (teamLang === 'en') return p.en;
    return 10;
  }
  const has = (p, t) => p.traits.includes(t);

  // Effektive Werte eines Spielers für ein Spiel
  function prepTeam(team, rng, opt, C) {
    const coach = team.coach || { dra: 30, dev: 30, mot: 30, tac: 30, man: 30 };
    const chem = team.chem;
    const champ = 0.85 + 0.15 * C.mastery / 100;
    const ps = ROLES.map(role => {
      const p = team.players.find(x => x.role === role);
      let [mec, lan, mac, tea, men] = p.s;
      if (has(p, 'Arrogant')) men += 3;
      if (has(p, 'Egoist')) { mec += 3; tea -= 4; }
      if (opt.pressure) {
        if (has(p, 'Clutch Player')) mec += 5;
        if (has(p, 'Choker')) men -= 5;
        if (has(p, 'Bühnentier')) mec += 3;
        if (has(p, 'Bühnenangst')) mec -= 4;
      }
      let sd = C.sigmaBase * (1.5 - men / 100);
      if (has(p, 'Hot-Headed')) sd *= 1.5;
      if (has(p, 'Tilt-Proof')) sd *= 0.75;
      if (opt.pressure && has(p, 'Clutch Player')) sd *= 0.5;
      const d = rng.gauss() * sd;
      const K = commK(p, team.lang);
      const fm = p.form != null ? clamp((p.form - C.formCenter) / C.formDiv, -4, 4) : 0;
      const base = [mec, lan, mac, tea, men].map(x => x * champ + d + fm);
      base[3] = base[3] * (0.80 + 0.40 * chem / 100) * (0.80 + 0.20 * K / 100);
      return { p, role, s: base, d, K, ovr: ovrOf(role, base), k: 0, de: 0, a: 0, gold: 500 };
    });
    return { team, coach, chem, ps, by: r => ps[ROLES.indexOf(r)] };
  }

  function draft(A, B, rng) {
    const pickArch = T => rng.pick(ARCH);
    const compScore = T => clamp(Math.round(rng.u() * 3 + 2 * T.coach.dra / 100), 0, 5);
    // Wer zuerst seine Comp festlegt, wird ausgelost; der andere kann kontern
    const aFirst = rng.u() < 0.5;
    const first = aFirst ? A : B, second = aFirst ? B : A;
    const a1 = pickArch(first);
    let a2;
    if (rng.u() < 0.30 + 0.50 * second.coach.dra / 100) { a2 = ARCH.slice().sort((x, y) => M[y][a1] - M[x][a1])[0]; } else a2 = rng.pick(ARCH);
    const aA = aFirst ? a1 : a2, aB = aFirst ? a2 : a1;
    return { A: { arch: aA, score: compScore(A) }, B: { arch: aB, score: compScore(B) } };
  }
  function compAt(dr, side, minute) {
    const me = dr[side], op = dr[side === 'A' ? 'B' : 'A'];
    const idx = minute < 25 ? 0 : minute < 35 ? 1 : 2;
    return me.score + CURVE[me.arch][idx] + M[me.arch][op.arch];
  }

  function simulateGame(teamA, teamB, opt, seed) {
    const C = Object.assign({}, DEFAULTS, opt.consts || {});
    const rng = makeRng(seed);
    const A = prepTeam(teamA, rng, opt, C), B = prepTeam(teamB, rng, opt, C);
    const S = { A, B };
    const log = [];
    const ev = (min, text, side, kind) => log.push({ min, text, side, kind });
    // Kill-Gold: 70 % an den Killer, 30 % an die Assists
    const payKill = (killer, assists) => { if (assists.length) { killer.gold += 0.7 * C.kill; assists.forEach(x => x.gold += 0.3 * C.kill / assists.length); } else killer.gold += C.kill; };
    const payTeam = (T, g) => T.ps.forEach(x => x.gold += g / 5);
    const FARM = { Top: 320, Jungle: 290, Mid: 340, ADC: 360, Support: 210 };
    const dr = draft(A, B, rng);
    ev(0, `Draft: ${teamA.short} spielt ${dr.A.arch} (Comp ${dr.A.score}), ${teamB.short} spielt ${dr.B.arch} (Comp ${dr.B.score})`, null, 'draft');

    // ---- Phase 2: Laning ----
    const early = (pp, i) => has(pp.p, 'Early-Game-Spezialist') ? 4 : 0;
    function laneVal(pp) { const e = early(pp); const lan = pp.s[1] + e + (has(pp.p, 'Lane Bully') ? 5 : 0); return 0.6 * lan + 0.4 * (pp.s[0] + e); }
    function L(T) {
      const top = laneVal(T.by('Top')), mid = laneVal(T.by('Mid'));
      const bot = 0.6 * laneVal(T.by('ADC')) + 0.4 * laneVal(T.by('Support'));
      return { Top: top, Mid: mid, Bot: bot };
    }
    function Jval(T) { const j = T.by('Jungle'); const e = early(j); return 0.6 * (j.s[2] + e) + 0.4 * (j.s[0] + e) + (has(j.p, 'Invader') ? 3 : 0); }
    const LA = L(A), LB = L(B), JA = Jval(A), JB = Jval(B);
    // Roamer: +3 auf schwächste andere Lane, −2 eigene
    [[A, LA, LB], [B, LB, LA]].forEach(([T, Lm, Lo]) => {
      ['Mid', 'Support'].forEach(r => { const pp = T.by(r); if (has(pp.p, 'Roamer')) { const own = r === 'Mid' ? 'Mid' : 'Bot'; const others = ['Top', 'Mid', 'Bot'].filter(x => x !== own); const weakest = others.sort((x, y) => (Lm[x] - Lo[x]) - (Lm[y] - Lo[y]))[0]; Lm[weakest] += 3; Lm[own] -= 2; } });
    });
    function plan(T, Lm, Lo, Jm, Jo, forced) {
      if (forced && forced !== 'Auto') return forced;
      const diffs = ['Top', 'Mid', 'Bot'].map(l => [l, Lm[l] - Lo[l]]).sort((a, b) => b[1] - a[1]);
      if (diffs[0][1] >= 3) return diffs[0][0];
      if (Jm >= Jo + 3) return 'Objectives';
      return diffs[2][0];
    }
    const planA = plan(A, LA, LB, JA, JB, opt.planA), planB = plan(B, LB, LA, JB, JA, opt.planB);
    ev(0, `Jungle-Plan: ${teamA.short} → ${planA}, ${teamB.short} → ${planB}`, null, 'plan');
    function prox(T, pl, J, lane) {
      if (pl === 'Objectives') return 0;
      if (pl === lane) return 0.10 * J;
      const lanePl = lane === 'Top' ? T.by('Top') : lane === 'Bot' ? T.by('ADC') : null;
      if (lanePl && has(lanePl.p, 'Weak-Side-Spezialist')) return 0.05 * J;
      return 0.025 * J;
    }
    const lanePlayers = (T, l) => l === 'Top' ? [T.by('Top')] : l === 'Mid' ? [T.by('Mid')] : [T.by('ADC'), T.by('Support')];
    const laneEff = {};
    let gold14 = 0;
    ['Top', 'Mid', 'Bot'].forEach(l => {
      const a = LA[l] + prox(A, planA, JA, l), b = LB[l] + prox(B, planB, JB, l);
      laneEff[l] = [a, b];
      gold14 += C.lane * (a - b);
    });
    gold14 += C.jgl * (JA - JB);
    // Lane-Vorsprung als zusätzlicher Farm der Laner
    ['Top', 'Mid', 'Bot'].forEach(l => { const v = C.lane * (laneEff[l][0] - laneEff[l][1]); const T = v >= 0 ? A : B; const ps = lanePlayers(T, l); if (ps.length > 1) { ps[0].gold += 0.7 * Math.abs(v); ps[1].gold += 0.3 * Math.abs(v); } else ps[0].gold += Math.abs(v); });
    { const v = C.jgl * (JA - JB); (v >= 0 ? A : B).by('Jungle').gold += Math.abs(v); }
    const timeline = new Array(61).fill(0); // Golddifferenz-Ereignisse pro Minute (A − B)
    let base14 = gold14;
    // Kill-Events in der Lane
    let firstBlood = false;
    const killEvents = [];
    ['Top', 'Mid', 'Bot'].forEach(l => {
      let n = rng.poisson(C.killsPerLane);
      const inv = (planA === l && has(A.by('Jungle').p, 'Invader')) || (planB === l && has(B.by('Jungle').p, 'Invader'));
      if (inv) n += 1;
      for (let i = 0; i < n; i++) {
        const [a, b] = laneEff[l];
        const winA = rng.u() < sig((a - b) / 10);
        const W_ = winA ? A : B, Lz = winA ? B : A, wPlan = winA ? planA : planB;
        const killers = lanePlayers(W_, l), victims = lanePlayers(Lz, l);
        let killer = killers.length > 1 ? (rng.u() < 0.6 ? killers[0] : killers[1]) : killers[0];
        const jg = W_.by('Jungle');
        if (wPlan === l) {
          // Gank-Anteil hängt an Jungler und Laner (siehe GDD)
          let share = C.gankShare;
          if (has(jg.p, 'Invader')) share += 0.08;
          if (has(jg.p, 'Early-Game-Spezialist')) share += 0.05;
          if (has(killer.p, 'Lane Bully')) share -= 0.08;
          if (has(killer.p, 'Carry')) share -= 0.05;
          if (has(killer.p, 'Egoist')) share -= 0.08;
          if (has(killer.p, 'Teamplayer')) share += 0.05;
          if (rng.u() < clamp(share, 0.05, 0.45)) killer = jg;
        }
        const victim = victims.length > 1 ? rng.weighted(victims, victims.map(v => (100 - v.s[4]) * (has(v.p, 'Risikoarm') ? 0.7 : 1))) : victims[0];
        killer.k++; victim.de++;
        const asl = killers.concat(wPlan === l ? [jg] : []).filter(x => x !== killer); asl.forEach(x => x.a++);
        payKill(killer, asl);
        const min = rng.int(3, 13);
        killEvents.push({ min, winA, killer, victim, lane: l });
      }
    });
    killEvents.sort((x, y) => x.min - y.min).forEach(e => {
      timeline[e.min] += (e.winA ? 1 : -1) * C.kill;
      const fb = !firstBlood ? 'First Blood! ' : ''; firstBlood = true;
      ev(e.min, `${fb}${e.killer.p.tag} tötet ${e.victim.p.tag} (${e.lane})`, e.winA ? 'A' : 'B', 'kill');
    });
    // Golddifferenz-Verlauf
    const goldAt = new Array(61).fill(0);
    let cum = 0;
    for (let m = 1; m <= 14; m++) { cum += timeline[m]; goldAt[m] = Math.round(base14 * m / 14 + cum); }
    let gd = goldAt[14];
    ev(14, `Nach dem Laning: ${gd >= 0 ? teamA.short : teamB.short} führt mit ${Math.abs(gd)} Gold`, gd >= 0 ? 'A' : 'B', 'phase');
    const leader14 = gd === 0 ? null : gd > 0 ? 'A' : 'B';

    // ---- Phase 3: Midgame ----
    const MW = { Top: 1, Jungle: 1.5, Mid: 1, ADC: 1, Support: 1.25 };
    function macro(T) {
      let s = 0, w = 0; T.ps.forEach(pp => { s += MW[pp.role] * pp.s[2]; w += MW[pp.role]; });
      let m = s / w;
      const sc = T.ps.filter(pp => has(pp.p, 'Shotcaller'));
      if (sc.length) m += 4 * Math.max(...sc.map(pp => pp.p.cha)) / 100;
      m += (T.coach.tac - 50) / 10;
      return m;
    }
    const MA = macro(A), MB = macro(B);
    const vis = T => T.ps.some(pp => has(pp.p, 'Vision Master')) ? 3 : 0;
    const drakes = { A: 0, B: 0 };
    const objs = [[15, 'Herold', 600], [17, 'Drache', 300], [20, 'Turm', 550], [22, 'Drache', 300], [24, 'Turm', 550]];
    let minute = 14, earlyObj = 0;
    const setGold = (m, val) => { for (let x = minute + 1; x <= m; x++) goldAt[x] = val; minute = m; };
    objs.forEach(([m, name, g]) => {
      let mA = MA + vis(A), mB = MB + vis(B);
      if (earlyObj < 3 && name !== 'Turm') { if (planA === 'Objectives') mA += 0.05 * JA; if (planB === 'Objectives') mB += 0.05 * JB; earlyObj++; }
      const pA = sig((mA - mB) / C.objDiv + gd / C.objGold + (compAt(dr, 'A', m) - compAt(dr, 'B', m)) / C.compDiv);
      const winA = rng.u() < pA;
      gd += (winA ? 1 : -1) * g; payTeam(winA ? A : B, g);
      if (name === 'Drache') drakes[winA ? 'A' : 'B']++;
      // Gelegentliches Scharmützel
      if (rng.u() < C.skirmish) {
        const W_ = winA ? A : B, Lz = winA ? B : A;
        const killer = rng.weighted(W_.ps, W_.ps.map(x => Math.max(1, x.s[0]))), victim = rng.weighted(Lz.ps, Lz.ps.map(x => Math.max(1, 100 - x.s[4]) * (has(x.p, 'Risikoarm') ? 0.7 : 1)));
        killer.k++; victim.de++; gd += (winA ? 1 : -1) * C.kill;
        const asl = W_.ps.filter(x => x !== killer && rng.u() < x.s[3] / 100 * 0.5); asl.forEach(x => x.a++); payKill(killer, asl);
      }
      setGold(m, gd);
      ev(m, `${winA ? teamA.short : teamB.short} sichert ${name}`, winA ? 'A' : 'B', 'obj');
    });

    // ---- Phase 4: Teamfights ----
    const pressure = { A: 0, B: 0 };
    let baronCd = 20, elderCd = 35, baronBuff = { A: -1, B: -1 };
    let winner = null, t = 25, fights = 0;
    function F(T, side, tm) {
      const ahead = side === 'A' ? gd > 0 : gd < 0;
      let f = 0;
      T.ps.forEach(pp => {
        let mec = pp.s[0];
        if (has(pp.p, 'Late-Game-Monster')) mec += 4;
        if (has(pp.p, 'Carry') && ahead) mec += 4;
        f += 0.5 * mec + 0.3 * pp.s[3] + 0.2 * pp.s[2];
      });
      if (T.ps.some(pp => has(pp.p, 'Engage Caller'))) f += 3;
      f += compAt(dr, side, tm) + drakes[side];
      if (baronBuff[side] >= tm) f += 5;
      return f;
    }
    while (!winner) {
      t += 1.2 + rng.u() * 1.8;
      const tm = Math.round(t);
      let fA = F(A, 'A', tm) + C.fightGold * gd / 1000;
      let fB = F(B, 'B', tm);
      let winA;
      let thrown = false;
      if (Math.abs(gd) > 5000) {
        const lead = gd > 0 ? A : B;
        const menAvg = lead.ps.reduce((a, x) => a + x.s[4], 0) / 5;
        if (rng.u() < C.throwBase * (1 - menAvg / 100)) { winA = gd < 0; thrown = true; }
      }
      if (!thrown) winA = rng.u() < sig((fA - fB) / C.fightDiv);
      fights++;
      const side = winA ? 'A' : 'B', other = winA ? 'B' : 'A';
      const W_ = S[side], Lz = S[other];
      const wasBehind = winA ? gd < 0 : gd > 0;
      let g = 800 + rng.u() * 700;
      if (wasBehind) g += C.shutdown * Math.abs(gd);
      // Kills: Sieger im Schnitt C.fightKills, Verlierer etwa ein Drittel davon
      const nk = Math.min(5, Math.max(1, rng.poisson(C.fightKills))), nb = Math.min(4, rng.poisson(C.fightKills / 3));
      const doKills = (Wt, Lt, n) => {
        for (let i = 0; i < n; i++) {
          const killer = rng.weighted(Wt.ps, Wt.ps.map(x => Math.max(1, x.s[0]) ** 2));
          const victim = rng.weighted(Lt.ps, Lt.ps.map(x => Math.max(1, 100 - x.s[4]) * (has(x.p, 'Risikoarm') ? 0.7 : 1)));
          killer.k++; victim.de++;
          const asl = Wt.ps.filter(x => x !== killer && rng.u() < x.s[3] / 100); asl.forEach(x => x.a++); payKill(killer, asl);
        }
      };
      doKills(W_, Lz, nk); doKills(Lz, W_, nb);
      payTeam(W_, g);
      g += (nk - nb) * C.kill;
      let objName = 'Turm', pr = 1;
      if (t >= elderCd && t >= 35) { objName = 'Elder Drache'; pr = 3; elderCd = t + 6; }
      else if (t >= baronCd) { objName = 'Baron'; pr = 2; baronCd = t + 6; baronBuff[side] = tm + 3; g += 1500; payTeam(W_, 1500); }
      pressure[side] += pr; pressure[other] = Math.max(0, pressure[other] - 1);
      gd += (winA ? 1 : -1) * Math.round(g);
      setGold(Math.min(60, tm), gd);
      const tag = thrown ? 'Throw! ' : wasBehind ? 'Comeback-Fight! ' : '';
      ev(tm, `${tag}${W_.team.short} gewinnt den Teamfight ${nk}:${nb} und holt ${objName}`, side, objName === 'Baron' || objName === 'Elder Drache' ? 'big' : 'fight');
      if (pressure[side] >= 4 || t >= 45) {
        winner = side;
        ev(tm, `${W_.team.short} zerstört den Nexus`, side, 'end');
      }
    }
    const dur = Math.round(t);
    for (let x = minute + 1; x <= Math.min(60, dur); x++) goldAt[x] = gd;
    const gold = goldAt.slice(0, Math.min(60, dur) + 1);

    // ---- Farm über die Spielzeit (für beide Teams gleich) ----
    [A, B].forEach(T => T.ps.forEach(x => x.gold += FARM[x.role] * t));
    const teamGold = T => Math.round(T.ps.reduce((a, x) => a + x.gold, 0));
    const teamKills = T => T.ps.reduce((a, x) => a + x.k, 0);
    // ---- Bewertung ----
    const rate = (T, side) => T.ps.map(pp => {
      const opp = S[side === 'A' ? 'B' : 'A'].by(pp.role);
      const kda = (pp.k + pp.a) / Math.max(1, pp.de);
      const Wn = winner === side ? 1 : -1;
      const raw = clamp(C.ratingBase + 5 * Wn + 0.4 * (pp.ovr - opp.ovr) + 2 * clamp(kda - (C.kdaBase[pp.role] ?? 3), -4, 4) + pp.d, 0, 100);
      const g = 100 - (100 - raw) * C.ratingCompress; // Skala nach oben gestaucht: höherer Boden, gleiche Spitze
      return { tag: pp.p.tag, role: pp.role, k: pp.k, d: pp.de, a: pp.a, kda, g: Math.round(g), K: pp.K, f: pp.p.f, gold: Math.round(pp.gold) };
    });
    const rA = rate(A, 'A'), rB = rate(B, 'B');
    const winList = winner === 'A' ? rA : rB;
    const mvp = winList.slice().sort((x, y) => y.g - x.g)[0].tag;
    return { winner, dur, gold, gold14: goldAt[14], leader14, log, draft: dr, plans: { A: planA, B: planB }, ratings: { A: rA, B: rB }, mvp, drakes, fights, teamGold: { A: teamGold(A), B: teamGold(B) }, kills: { A: teamKills(A), B: teamKills(B) } };
  }

  function simulateSeries(A, B, bestOf, opt, seed) {
    const need = Math.ceil(bestOf / 2); const games = []; let wa = 0, wb = 0, i = 0;
    while (wa < need && wb < need) {
      const decider = (wa === need - 1 && wb === need - 1);
      const o = Object.assign({}, opt, { pressure: opt.pressure || (bestOf > 1 && decider) });
      // Seitenwechsel: im Spiel 2,4 tauscht Blau/Rot nur visuell; Simulation bleibt A gegen B
      const g = simulateGame(A, B, o, (seed + i * 7919) >>> 0);
      games.push(g); if (g.winner === 'A') wa++; else wb++; i++;
    }
    return { games, wa, wb };
  }

  function teamOvr(team) { return team.players.reduce((a, p) => a + ovrOf(p.role, p.s), 0) / 5; }

  G.RiftSim = { ROLES, W, ARCH, CURVE, M, DEFAULTS, ovrOf, teamOvr, simulateGame, simulateSeries, makeRng, commK };
})(typeof window !== 'undefined' ? window : globalThis);
