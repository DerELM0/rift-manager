// Rift Manager – Saison-Loop (Prototyp, Schritt 2 des Plans)
(function (G) {
  'use strict';
  const S = G.RiftSim;
  const ROLES = S.ROLES;
  const clone = o => JSON.parse(JSON.stringify(o));
  const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
  const FOCUS = { Top: 1, Jungle: 2, Mid: 0, ADC: 0, Support: 3 };
  const AGEF = a => a <= 19 ? 1.3 : a <= 22 ? 1.0 : a <= 25 ? 0.6 : a <= 28 ? 0.2 : 0.1;

  // Formate nach den echten Ligen 2026 (vereinfacht: Playoffs als Top-6-Bracket)
  const PRESETS = {
    LCK: [{ id: 'lck', name: 'Saison, Runden 1–4 (Bo3)', note: 'Runden 1–2: doppelte Runde aller 10 Teams. Runden 3–4: Legend Group (Platz 1–5) und Rise Group (Platz 6–10) spielen getrennt eine doppelte Runde, die Bilanz läuft weiter. Alles Bo3.', bestOf: 1 }],
    LPL: [{ id: 'lpl', name: 'Split mit Ascend und Nirvana (Bo3)', note: 'Die 8 stärksten Teams bilden die Ascend Group, die übrigen die Nirvana Group. Beide spielen eine doppelte Runde im Bo3. Die Top 6 der Ascend Group erreichen die Playoffs.', bestOf: 3 }],
    LEC: [{ id: 'single3', name: 'Spring/Summer: einfache Runde, Bo3', note: 'Einfache Runde im Bo3, die Top 6 erreichen die Playoffs.', bestOf: 3 }, { id: 'single1', name: 'Versus: einfache Runde, Bo1', note: 'Einfache Runde im Bo1, die Top 6 erreichen die Playoffs.', bestOf: 1 }],
    LCS: [{ id: 'single3', name: 'Spring/Summer: einfache Runde, Bo3', note: 'Einfache Runde im Bo3, die Top 6 erreichen die Playoffs.', bestOf: 3 }],
    CBLOL: [{ id: 'single3', name: 'Split 1/2: einfache Runde, Bo3', note: 'Einfache Runde im Bo3, die Top 6 erreichen die Playoffs.', bestOf: 3 }, { id: 'single1', name: 'CBLOL Cup: einfache Runde, Bo1', note: 'Einfache Runde im Bo1, die Top 6 erreichen die Playoffs.', bestOf: 1 }],
    LCP: [{ id: 'single3', name: 'Split 1/2: einfache Runde, Bo3', note: 'Einfache Runde im Bo3, die Top 6 erreichen die Playoffs.', bestOf: 3 }]
  };
  PRESETS.LCK[0].bestOf = 3;

  function roundRobin(ids) {
    const t = ids.slice(); if (t.length % 2) t.push(null);
    const n = t.length, rounds = [];
    for (let r = 0; r < n - 1; r++) {
      const pairs = [];
      for (let i = 0; i < n / 2; i++) { const a = t[i], b = t[n - 1 - i]; if (a && b) pairs.push(r % 2 ? [b, a] : [a, b]); }
      rounds.push(pairs); t.splice(1, 0, t.pop());
    }
    return rounds;
  }
  const dbl = rounds => rounds.concat(rounds.map(r => r.map(([a, b]) => [b, a])));
  // Mehrere Gruppen parallel: Runde i aller Gruppen zu einem Spieltag zusammenfassen
  function merge(...lists) { const n = Math.max(...lists.map(l => l.length)); const out = []; for (let i = 0; i < n; i++) out.push([].concat(...lists.map(l => l[i] || []))); return out; }
  function toWeeks(rounds, perWeek = 2) { const w = []; for (let i = 0; i < rounds.length; i += perWeek) w.push(rounds.slice(i, i + perWeek)); return w; }

  function create(teams, opt) {
    const rng = S.makeRng(opt.seed >>> 0);
    const T = teams.map(t => {
      const c = clone(t);
      c.players.forEach(p => { p.form = opt.consts.formCenter ?? 71; p.start = { s: p.s.slice(), ovr: S.ovrOf(p.role, p.s), form: p.form }; p.games = 0; p.sumG = 0; p.mvps = 0; p.k = 0; p.d = 0; p.a = 0; p.gold = 0; p.gr = []; p.hist = [{ w: 0, form: p.form, ovr: p.start.ovr }]; });
      c.chemStart = c.chem; c.rec = { w: 0, l: 0, mw: 0, ml: 0, last: [], streak: 0 }; c.group = null;
      return c;
    });
    const shuffle = a => a.map(x => [rng.u(), x]).sort((p, q) => p[0] - q[0]).map(x => x[1]);
    const ids = shuffle(T.map(t => t.short));
    const st = { opt, teams: T, weeks: [], week: 0, results: [], playoffs: null, done: false, seedCtr: (opt.seed >>> 0) * 1000 + 1, phase: 1, rng };
    const p = opt.preset;
    if (p === 'lck') { st.weeks = toWeeks(dbl(roundRobin(ids))); st.phase2Pending = true; }
    else if (p === 'lpl') {
      const byOvr = T.slice().sort((a, b) => S.teamOvr(b) - S.teamOvr(a));
      const asc = byOvr.slice(0, 8), nir = byOvr.slice(8); asc.forEach(t => t.group = 'Ascend'); nir.forEach(t => t.group = 'Nirvana');
      st.weeks = toWeeks(merge(dbl(roundRobin(shuffle(asc.map(t => t.short)))), dbl(roundRobin(shuffle(nir.map(t => t.short))))));
    }
    else if (p === 'double1') st.weeks = toWeeks(dbl(roundRobin(ids)));
    else st.weeks = toWeeks(roundRobin(ids));
    return st;
  }
  const team = (st, sh) => st.teams.find(t => t.short === sh);

  function applyGame(st, A, B, g) {
    const C = Object.assign({}, S.DEFAULTS, st.opt.consts);
    [[A, 'A'], [B, 'B']].forEach(([T, side]) => {
      const mot = (T.coach || { mot: 30 }).mot;
      g.ratings[side].forEach(r => {
        const p = T.players.find(x => x.tag === r.tag);
        // Bewertung wirkt verstärkt auf die Form; Motivation des Coaches dämpft Einbrüche
        let target = C.formCenter + C.formAmp * (r.g - C.formCenter);
        if (target < p.form) target = p.form - (p.form - target) * (1 - 0.4 * mot / 100);
        p.form = clamp((1 - C.formWeight) * p.form + C.formWeight * target, 25, 99);
        p.games++; p.sumG += r.g; p.k += r.k; p.d += r.d; p.a += r.a; p.gold += r.gold; p.gr.push(Math.round(r.g));
        if (r.tag === g.mvp) p.mvps++;
      });
    });
  }

  function seriesMorale(st, W, L) {
    const C = Object.assign({}, S.DEFAULTS, st.opt.consts);
    W.rec.streak = W.rec.streak > 0 ? W.rec.streak + 1 : 1; L.rec.streak = L.rec.streak < 0 ? L.rec.streak - 1 : -1;
    // Moral: Sieg hebt, Niederlage drückt Form; Serien verstärken das
    W.players.forEach(p => p.form = clamp(p.form + C.morale + (W.rec.streak >= 3 ? 1 : 0), 25, 99));
    L.players.forEach(p => p.form = clamp(p.form - C.morale - (L.rec.streak <= -3 ? 1 : 0), 25, 99));
    // Chemistry: Niederlagen bedeuten Stress im Team, ein starkes Man-Management fängt das ab
    const manL = (L.coach || { man: 30 }).man;
    L.chem = clamp(L.chem - C.chemLoss * (1 - 0.4 * manL / 100) * (L.rec.streak <= -3 ? 1.3 : 1) * Math.min(1, L.chem / 50), 15, 100); // unter 50 bröckelt es langsamer
    W.chem = clamp(W.chem + C.chemWin, 0, 100);
  }

  function playSeries(st, a, b, bestOf, pressure, regular) {
    const A = team(st, a), B = team(st, b);
    const res = S.simulateSeries(A, B, bestOf, { pressure, consts: st.opt.consts }, (st.seedCtr += 7919) >>> 0);
    res.games.forEach(g => applyGame(st, A, B, g));
    const winner = res.wa > res.wb ? a : b;
    seriesMorale(st, team(st, winner), team(st, winner === a ? b : a));
    return { a, b, bestOf, wa: res.wa, wb: res.wb, games: res.games, winner };
  }

  function weeklyDevelopment(st) {
    const C = Object.assign({}, S.DEFAULTS, st.opt.consts);
    const rng = st.rng;
    st.teams.forEach(T => {
      const c = T.coach || { dev: 30, man: 30 };
      const mdev = 0.6 + 0.8 * c.dev / 100;
      const mentor = T.players.some(p => p.traits.includes('Mentor') && p.age >= 24);
      T.players.forEach(p => {
        const ovr = S.ovrOf(p.role, p.s);
        let B = 1; if (mentor && p.age <= 21) B += 0.15; if (p.traits.includes('Grinder')) B += 0.10; if (p.traits.includes('Faul')) B -= 0.20; if (p.traits.includes('Perfektionist')) B += 0.15;
        B *= 1 + (p.form - C.formCenter) / 60; // gute Form trainiert besser
        let age = p.age; if (p.traits.includes('Late Bloomer') && age <= 25) age = Math.min(age, 22);
        const d = C.trainBase * AGEF(age) * mdev * B * Math.max(0, (p.pot - ovr) / 20);
        // Wochenschwankung: Tagesform im Training, Selbstvertrauen, kleine Rückschläge
        p.s = p.s.map((x, i) => clamp(x + (i === FOCUS[p.role] ? d : 0.3 * d) + rng.gauss() * C.statNoise, 20, 99));
        // Form driftet zufällig: kleine Krisen und Höhenflüge
        p.form = clamp(p.form + rng.gauss() * C.formDrift, 25, 99);
        p.hist.push({ w: st.week + 1, form: p.form, ovr: S.ovrOf(p.role, p.s) });
      });
      const ps = T.players; let sum = 0, n = 0;
      for (let i = 0; i < 5; i++) for (let j = i + 1; j < 5; j++) {
        const a = ps[i], b = ps[j];
        const shared = a.langs.some(l => b.langs.includes(l));
        const kmin = shared ? 100 : Math.min(S.commK(a, T.lang), S.commK(b, T.lang));
        const L = 0.5 + 0.5 * kmin / 100;
        let f = 1; [a, b].forEach(p => { if (p.traits.includes('Teamplayer')) f *= 1.3; if (p.traits.includes('Lone Wolf')) f *= 0.5; if (p.traits.includes('Arrogant')) f *= 0.8; });
        sum += C.chemGrowth * (0.5 + (a.cha + b.cha) / 200) * L * (0.8 + 0.4 * c.man / 100) * f; n++;
      }
      T.chem = clamp(T.chem + sum / n * (1 - T.chem / 110), 0, 100);
      T.players.forEach(p => { if (!p.langs.includes(T.lang) && T.lang === 'en') p.en = Math.min(100, p.en + (p.age <= 21 ? 2.5 : 1.5) * (p.traits.includes('Sprachtalent') ? 2 : 1)); });
    });
  }

  const groupRank = g => g === 'Legend' || g === 'Ascend' ? 0 : g === 'Rise' || g === 'Nirvana' ? 1 : 0;
  function standings(st) {
    return st.teams.slice().sort((x, y) => (groupRank(x.group) - groupRank(y.group)) || (y.rec.w - x.rec.w) || ((y.rec.mw - y.rec.ml) - (x.rec.mw - x.rec.ml)) || (S.teamOvr(y) - S.teamOvr(x)));
  }

  function startPhase2(st) {
    const tab = standings(st);
    const leg = tab.slice(0, 5), rise = tab.slice(5);
    leg.forEach(t => t.group = 'Legend'); rise.forEach(t => t.group = 'Rise');
    const rounds = merge(dbl(roundRobin(leg.map(t => t.short))), dbl(roundRobin(rise.map(t => t.short))));
    st.weeks = st.weeks.concat(toWeeks(rounds)); st.phase = 2; st.phase2Pending = false;
  }

  function playWeek(st) {
    if (st.week >= st.weeks.length) {
      if (st.phase2Pending) startPhase2(st); else return false;
    }
    const bo = st.opt.bestOf;
    const week = { n: st.week + 1, days: [], phase: st.phase };
    st.weeks[st.week].forEach(round => {
      week.days.push(round.map(([a, b]) => {
        const r = playSeries(st, a, b, bo, false, true);
        const W = team(st, r.winner), L = team(st, r.winner === a ? b : a);
        W.rec.w++; L.rec.l++; W.rec.last.push('S'); L.rec.last.push('N');
        const A = team(st, a), B = team(st, b); A.rec.mw += r.wa; A.rec.ml += r.wb; B.rec.mw += r.wb; B.rec.ml += r.wa;
        return r;
      }));
    });
    weeklyDevelopment(st);
    st.results.push(week); st.week++;
    return true;
  }
  const totalWeeks = st => st.weeks.length + (st.phase2Pending ? 4 : 0);
  const regularDone = st => st.week >= st.weeks.length && !st.phase2Pending;

  function playoffSeeds(st) {
    const tab = standings(st);
    return tab.slice(0, 6).map(t => t.short); // Legend 1–5 + Rise 1 bzw. Ascend 1–6 bzw. Top 6
  }
  function startPlayoffs(st) {
    const seeds = playoffSeeds(st);
    st.playoffs = { seeds, rounds: [] };
    const qf = [playSeries(st, seeds[2], seeds[5], 5, true), playSeries(st, seeds[3], seeds[4], 5, true)];
    st.playoffs.rounds.push({ name: 'Viertelfinale', series: qf });
    const qw = qf.map(s => s.winner).sort((x, y) => seeds.indexOf(x) - seeds.indexOf(y));
    const sf = [playSeries(st, seeds[0], qw[1], 5, true), playSeries(st, seeds[1], qw[0], 5, true)];
    st.playoffs.rounds.push({ name: 'Halbfinale', series: sf });
    const fin = playSeries(st, sf[0].winner, sf[1].winner, 5, true);
    st.playoffs.rounds.push({ name: 'Finale', series: [fin] });
    st.playoffs.champion = fin.winner;
    st.done = true;
  }

  function awards(st) {
    const all = []; st.teams.forEach(T => T.players.forEach(p => all.push({ p, T })));
    const minG = Math.max(1, Math.floor(Math.max(...all.map(x => x.p.games)) * 0.5));
    const elig = all.filter(x => x.p.games >= minG);
    const avg = x => x.p.sumG / x.p.games;
    const mvp = elig.slice().sort((a, b) => (b.p.mvps - a.p.mvps) || (avg(b) - avg(a)))[0];
    const allPro = ROLES.map(r => elig.filter(x => x.p.role === r).sort((a, b) => avg(b) - avg(a))[0]);
    const rookie = elig.filter(x => x.p.age <= 19).sort((a, b) => avg(b) - avg(a))[0];
    const improved = all.map(x => ({ x, d: S.ovrOf(x.p.role, x.p.s) - x.p.start.ovr })).sort((a, b) => b.d - a.d)[0];
    return { mvp, allPro, rookie, improved, avg };
  }

  G.RiftSeason = { PRESETS, create, playWeek, startPlayoffs, standings, awards, team, totalWeeks, regularDone };
})(typeof window !== 'undefined' ? window : globalThis);
