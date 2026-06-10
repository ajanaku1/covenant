import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { INTER } from "./fonts";

type SubtitleEntry = { text: string; startFrame: number; endFrame: number };

// Sentence-level timing estimated from word counts over AUDIO_DURATIONS (see SCRIPT.md).
// Frames are scene-local (each scene renders its own <Subtitles>).
export const SUBS: Record<string, SubtitleEntry[]> = {
  hook: [
    { text: "Every smart contract still waits for someone to push the button.", startFrame: 0, endFrame: 117 },
    { text: "A keeper. An oracle. A human.", startFrame: 117, endFrame: 181 },
    { text: "Covenant is an agreement that needs nobody. Not even you.", startFrame: 181, endFrame: 287 },
  ],
  problem: [
    { text: "Real deals are written in English.", startFrame: 0, endFrame: 66 },
    { text: "“Pay the freelancer when the site is live.”", startFrame: 66, endFrame: 155 },
    { text: "Normally you translate fuzzy reality into brittle Solidity, then babysit it with oracles and cron jobs.", startFrame: 155, endFrame: 387 },
    { text: "Covenant skips all of that.", startFrame: 387, endFrame: 442 },
  ],
  authoring: [
    { text: "You write the deal in plain English.", startFrame: 0, endFrame: 71 },
    { text: "Covenant extracts the parties, the escrow, the deadline, and the clause — and you fund it once.", startFrame: 71, endFrame: 242 },
    { text: "That is the last transaction anyone ever sends.", startFrame: 242, endFrame: 323 },
    { text: "The clause stays English, because this judge can actually read.", startFrame: 323, endFrame: 505 },
  ],
  loop: [
    { text: "Here is the loop.", startFrame: 0, endFrame: 46 },
    { text: "Covenant schedules its own wake-up with Somnia's reactivity layer.", startFrame: 46, endFrame: 150 },
    { text: "At check time, the chain calls the contract.", startFrame: 150, endFrame: 242 },
    { text: "It sends real evidence — the live website — to a panel of validator LLMs.", startFrame: 242, endFrame: 415 },
    { text: "Each scores the clause independently.", startFrame: 415, endFrame: 473 },
    { text: "Covenant takes the median — no single judge can swing a payout.", startFrame: 473, endFrame: 601 },
  ],
  onchain: [
    { text: "This is real, on Somnia testnet.", startFrame: 0, endFrame: 69 },
    { text: "The singleton holds every schedule and one 32-STT buffer.", startFrame: 69, endFrame: 172 },
    { text: "Escrow is walled off — it can never be spent on gas.", startFrame: 172, endFrame: 298 },
    { text: "Every judgment links to a public receipt — per-validator scores, on the Somnia agent explorer.", startFrame: 298, endFrame: 503 },
  ],
  settlement: [
    { text: "And then it just... happens.", startFrame: 0, endFrame: 57 },
    { text: "The contract wakes itself, the panel scores the clause, and the escrow moves to the freelancer.", startFrame: 57, endFrame: 273 },
    { text: "Count the transactions we sent after funding: zero.", startFrame: 273, endFrame: 364 },
    { text: "The agreement enforced itself.", startFrame: 364, endFrame: 410 },
  ],
  close: [
    { text: "Covenant. Agreements that read the world and pay themselves.", startFrame: 0, endFrame: 118 },
    { text: "Built on Somnia for the Agentathon.", startFrame: 118, endFrame: 196 },
    { text: "The code is public — covenant-beta.vercel.app.", startFrame: 196, endFrame: 275 },
    { text: "Write a deal in a sentence... and walk away.", startFrame: 275, endFrame: 392 },
  ],
};

export const Subtitles: React.FC<{ scene: keyof typeof SUBS }> = ({ scene }) => {
  const frame = useCurrentFrame();
  const active = SUBS[scene].find((e) => frame >= e.startFrame && frame < e.endFrame);
  if (!active) return null;

  return (
    <AbsoluteFill style={{ justifyContent: "flex-end", alignItems: "center", zIndex: 50 }}>
      <div
        style={{
          background: "rgba(0, 0, 0, 0.65)",
          borderRadius: 8,
          padding: "10px 24px",
          marginBottom: 60,
          maxWidth: 1400,
        }}
      >
        <div
          style={{
            fontFamily: INTER,
            fontSize: 28,
            fontWeight: 600,
            color: "#ffffff",
            textAlign: "center",
            lineHeight: 1.4,
          }}
        >
          {active.text}
        </div>
      </div>
    </AbsoluteFill>
  );
};
