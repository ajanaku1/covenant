# Covenant — Storyboard

Strategy C (TransitionSeries + per-scene audio, 24-frame crossfade). 1920x1080 @ 30fps.
Theme: dark indigo. bg #0a0a14, accent #5b51e8, teal #14b8a6 for "met/released" states.

| # | Scene | Visual | Assets |
|---|-------|--------|--------|
| 1 | hook | Dark bg, orbs. "What if a contract needed nobody?" -> brand reveal "COVENANT" + tagline + Somnia badge. | logo text only |
| 2 | problem | Side-by-side contrast. Left (red x): formalize English into Solidity, run keepers, trust an oracle, babysit forever. Right (green +): write English, fund once, walk away. | none |
| 3 | authoring | BrowserFrame: live UI recording — typing the canonical agreement, "Read it", scaffold confirm card. FloatingCallouts: "Plain English clause", "Fund once - last tx ever". | assets/authoring.mp4 (playwright recording) |
| 4 | loop | Architecture: four-stage loop Wake -> Perceive -> Judge -> Act as glass cards with arrows; under Judge, 3 validator chips each showing a score, median highlighted. | none (built in code) |
| 5 | onchain | BlockExplorer-style panels: deployed contract address + real createAgreement tx hash + escrow/buffer stats; right panel: receipt screenshot with per-validator scores. | assets/receipt.png, real tx hashes |
| 6 | settlement | [PLACEHOLDER] Watch dashboard recording: milestone flips to "clause satisfied -> released", payee balance appears, "0 txns since you funded it" banner. Until redeploy: static watch.png + animated state chips marked SIMULATION in DECISIONS.md — replace with real footage. | assets/settlement.mp4 (PENDING) |
| 7 | close | Corner brackets, brand gradient text, stats row (1 contract / 0 post-deploy txs / 3-validator median), URL + "Built for the Somnia Agentathon", slow fade to black. | logo text |

Scene durations come from audio (ffprobe) + 45-frame gap. Close gets +60 frames hold for the fade.
