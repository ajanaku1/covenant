import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring, interpolate } from "remotion";
import { COLORS } from "../constants";
import { INTER, MONO } from "../fonts";
import { AnimatedBackground } from "../components/AnimatedBackground";
import { GlowText } from "../components/GlowText";
import { GlassCard } from "../components/GlassCard";

const STAGES = [
  { label: "WAKE", detail: "The chain calls the contract at the scheduled time. No tx sent.", color: COLORS.accentBright, enterFrame: 60 },
  { label: "PERCEIVE", detail: "It fetches real evidence — the live website — via an on-chain agent.", color: COLORS.cyan, enterFrame: 150 },
  { label: "JUDGE", detail: "A validator LLM panel scores the English clause 0–100.", color: COLORS.amber, enterFrame: 240 },
  { label: "ACT", detail: "Median ≥ threshold → release. Past deadline → refund. Then re-arm.", color: COLORS.teal, enterFrame: 330 },
];

const SCORES = [
  { v: 84, delay: 410 },
  { v: 86, delay: 432 },
  { v: 91, delay: 454 },
];

export const Loop: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const medianProg = spring({ frame: frame - 490, fps, config: { damping: 14, stiffness: 80 } });
  const medianOp = interpolate(medianProg, [0, 0.4], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ background: COLORS.bg }}>
      <AnimatedBackground />
      <AbsoluteFill style={{ alignItems: "center", paddingTop: 80 }}>
        <GlowText text="The loop" fontSize={52} color={COLORS.white} delay={5} />
        <GlowText
          text="Wake → Perceive → Judge → Act"
          fontSize={26}
          color={COLORS.offWhite}
          delay={25}
          fontWeight={500}
          fontFamily={MONO}
          style={{ marginTop: 10 }}
        />
      </AbsoluteFill>

      <AbsoluteFill style={{ flexDirection: "row", justifyContent: "center", alignItems: "center", gap: 26, paddingTop: 30 }}>
        {STAGES.map((s, i) => {
          const arrowOp = interpolate(frame, [s.enterFrame + 50, s.enterFrame + 70], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          return (
            <React.Fragment key={s.label}>
              <GlassCard delay={s.enterFrame} borderColor={`${s.color}44`} style={{ width: 330, height: 240, padding: "30px 28px" }}>
                <div style={{ fontFamily: MONO, fontSize: 17, fontWeight: 700, color: s.color, letterSpacing: 4, marginBottom: 16 }}>
                  {s.label}
                </div>
                <div style={{ fontFamily: INTER, fontSize: 20, color: COLORS.white, lineHeight: 1.45 }}>{s.detail}</div>
              </GlassCard>
              {i < STAGES.length - 1 && (
                <div style={{ fontFamily: MONO, fontSize: 36, color: COLORS.accentBright, opacity: arrowOp }}>→</div>
              )}
            </React.Fragment>
          );
        })}
      </AbsoluteFill>

      {/* Validator panel + median, under the JUDGE card */}
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "flex-end", paddingBottom: 95 }}>
        <div style={{ display: "flex", gap: 18, alignItems: "center" }}>
          {SCORES.map((s, i) => {
            const p = spring({ frame: frame - s.delay, fps, config: { damping: 14, stiffness: 90 } });
            const op = interpolate(p, [0, 0.4], [0, 1], { extrapolateRight: "clamp" });
            return (
              <div
                key={i}
                style={{
                  opacity: op,
                  transform: `scale(${interpolate(p, [0, 1], [0.93, 1])})`,
                  fontFamily: MONO,
                  fontSize: 20,
                  color: COLORS.offWhite,
                  border: `1px solid ${COLORS.border}`,
                  borderRadius: 10,
                  padding: "12px 20px",
                  background: COLORS.bgCard,
                }}
              >
                validator {i + 1} · <span style={{ color: COLORS.amber, fontWeight: 700 }}>{s.v}</span>
              </div>
            );
          })}
          <div
            style={{
              opacity: medianOp,
              fontFamily: MONO,
              fontSize: 20,
              fontWeight: 700,
              color: COLORS.bg,
              borderRadius: 10,
              padding: "12px 22px",
              background: COLORS.teal,
              boxShadow: `0 0 30px ${COLORS.teal}50`,
            }}
          >
            median 86 — no single judge decides
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
