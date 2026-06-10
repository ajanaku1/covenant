# Deferred Decisions

## Decision: Settlement scene uses a static placeholder
**Recommendation:** Scene 6 (settlement) uses the watch-dashboard screenshot with an animated
"released" banner and the "0 transactions" stat, because the redeployed contract (wake-routing
fix) is waiting on ~33.5 STT testnet funding — no real settlement footage exists yet.
**Rationale:** Ship a complete render now; swap in real footage the moment the autonomous run
settles on-chain. The narration already matches the real behavior.
**Override:** Record `public/assets/settlement.mp4` (watch dashboard flipping to released, real
receipt link), then replace the `<Img watch.png>` block in `src/scenes/Settlement.tsx` with an
`<OffthreadVideo>` like Authoring.tsx. Re-render.
**Affected files:** src/scenes/Settlement.tsx, public/assets/settlement.mp4

## Decision: TTS = edge-tts (en-US-AndrewMultilingualNeural, +12% rate)
**Recommendation:** No Gemini MCP / Azure / ElevenLabs credentials on this machine; edge-tts
gives free Microsoft neural voices.
**Override:** Set AZURE_SPEECH_KEY and regenerate per SCRIPT.md, update AUDIO_DURATIONS from
ffprobe.
**Affected files:** public/audio/*.mp3, src/constants.ts (AUDIO_DURATIONS)

## Decision: Validator scores in the Loop scene (84/86/91, median 86)
**Recommendation:** Illustrative numbers in an explainer diagram, not presented as on-chain data.
The OnChain scene shows only real data (address, tx hash, real receipt screenshot).
**Override:** After the real run, replace with the actual panel scores from the receipt.
**Affected files:** src/scenes/Loop.tsx (SCORES)

## Decision: Video length ~2:02
**Recommendation:** Brief requires 2–5 min; current cut lands just over 2:00 via scene holds.
**Override:** Extend SCENE_DURATIONS holds in constants.ts.
