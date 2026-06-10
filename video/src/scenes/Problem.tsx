import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring, interpolate } from "remotion";
import { COLORS } from "../constants";
import { INTER } from "../fonts";
import { AnimatedBackground } from "../components/AnimatedBackground";
import { GlowText } from "../components/GlowText";
import { GlassCard } from "../components/GlassCard";

const OLD_WAY = [
  "Translate fuzzy English into brittle Solidity",
  "Run keepers and cron jobs forever",
  "Trust an oracle to describe reality",
  "Babysit the contract until it settles",
];

const NEW_WAY = [
  "Write the deal in plain English",
  "Fund the escrow once",
  "A validator LLM panel reads the evidence",
  "Walk away — it enforces itself",
];

const Row: React.FC<{ text: string; good: boolean; delay: number }> = ({ text, good, delay }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const prog = spring({ frame: frame - delay, fps, config: { damping: 18, stiffness: 150 } });
  const op = interpolate(prog, [0, 0.4], [0, 1], { extrapolateRight: "clamp" });
  const x = interpolate(prog, [0, 1], [good ? 18 : -18, 0]);
  return (
    <div
      style={{
        display: "flex",
        gap: 14,
        alignItems: "baseline",
        marginBottom: 22,
        opacity: op,
        transform: `translateX(${x}px)`,
      }}
    >
      <span style={{ fontFamily: INTER, fontSize: 24, fontWeight: 800, color: good ? COLORS.teal : COLORS.red }}>
        {good ? "+" : "x"}
      </span>
      <span style={{ fontFamily: INTER, fontSize: 24, color: COLORS.white, lineHeight: 1.35 }}>{text}</span>
    </div>
  );
};

export const Problem: React.FC = () => {
  const frame = useCurrentFrame();
  const dividerOp = interpolate(frame, [60, 85], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ background: COLORS.bg }}>
      <AnimatedBackground />
      <AbsoluteFill style={{ alignItems: "center", paddingTop: 90 }}>
        <GlowText text="Real deals are written in English." fontSize={48} color={COLORS.white} delay={5} />
      </AbsoluteFill>
      <AbsoluteFill style={{ flexDirection: "row", justifyContent: "center", alignItems: "center", gap: 60, paddingTop: 90 }}>
        <GlassCard delay={20} borderColor={`${COLORS.red}33`} style={{ width: 620, padding: "36px 40px" }}>
          <div style={{ fontFamily: INTER, fontSize: 19, fontWeight: 700, color: COLORS.red, letterSpacing: 3, marginBottom: 26 }}>
            THE OLD WAY
          </div>
          {OLD_WAY.map((t, i) => (
            <Row key={i} text={t} good={false} delay={35 + i * 15} />
          ))}
        </GlassCard>
        <div
          style={{
            width: 2,
            height: 380,
            background: `linear-gradient(180deg, transparent, ${COLORS.accent}, transparent)`,
            opacity: dividerOp,
          }}
        />
        <GlassCard delay={95} borderColor={`${COLORS.teal}33`} style={{ width: 620, padding: "36px 40px" }}>
          <div style={{ fontFamily: INTER, fontSize: 19, fontWeight: 700, color: COLORS.teal, letterSpacing: 3, marginBottom: 26 }}>
            COVENANT
          </div>
          {NEW_WAY.map((t, i) => (
            <Row key={i} text={t} good delay={110 + i * 15} />
          ))}
        </GlassCard>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
