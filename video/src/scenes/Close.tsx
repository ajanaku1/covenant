import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate } from "remotion";
import { COLORS, ONCHAIN, SCENE_DURATIONS } from "../constants";
import { INTER, MONO } from "../fonts";
import { AnimatedBackground } from "../components/AnimatedBackground";
import { GlowText } from "../components/GlowText";

const STATS = [
  { v: "1", k: "singleton contract" },
  { v: "0", k: "post-deploy transactions" },
  { v: "3", k: "validator median judge" },
];

const Bracket: React.FC<{ corner: "tl" | "tr" | "bl" | "br"; opacity: number }> = ({ corner, opacity }) => {
  const pos: React.CSSProperties = {
    tl: { top: 60, left: 60, borderRight: "none", borderBottom: "none" },
    tr: { top: 60, right: 60, borderLeft: "none", borderBottom: "none" },
    bl: { bottom: 60, left: 60, borderRight: "none", borderTop: "none" },
    br: { bottom: 60, right: 60, borderLeft: "none", borderTop: "none" },
  }[corner];
  return (
    <div
      style={{
        position: "absolute",
        width: 55,
        height: 55,
        border: `2px solid ${COLORS.accent}66`,
        opacity,
        ...pos,
      }}
    />
  );
};

export const Close: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const dur = SCENE_DURATIONS.close;

  const bracketOp = interpolate(frame, [0, 25], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const fadeToBlack = interpolate(frame, [dur - 60, dur - 5], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ background: COLORS.bg }}>
      <AnimatedBackground />
      {(["tl", "tr", "bl", "br"] as const).map((c) => (
        <Bracket key={c} corner={c} opacity={bracketOp} />
      ))}

      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", flexDirection: "column" }}>
        <div
          style={{
            fontFamily: INTER,
            fontSize: 96,
            fontWeight: 900,
            letterSpacing: 5,
            background: `linear-gradient(135deg, ${COLORS.accentBright}, ${COLORS.accent}, ${COLORS.teal})`,
            backgroundClip: "text",
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
            opacity: interpolate(frame, [5, 30], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
          }}
        >
          COVENANT
        </div>
        <GlowText
          text="Agreements that read the world and pay themselves"
          fontSize={28}
          color={COLORS.offWhite}
          delay={25}
          fontWeight={500}
          style={{ marginBottom: 56 }}
        />

        <div style={{ display: "flex", gap: 70, marginBottom: 60 }}>
          {STATS.map((s, i) => {
            const op = interpolate(frame, [45 + i * 18, 65 + i * 18], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            });
            return (
              <div key={s.k} style={{ textAlign: "center", opacity: op }}>
                <div style={{ fontFamily: MONO, fontSize: 56, fontWeight: 700, color: COLORS.accentBright }}>{s.v}</div>
                <div style={{ fontFamily: INTER, fontSize: 18, color: COLORS.muted, marginTop: 6 }}>{s.k}</div>
              </div>
            );
          })}
        </div>

        <GlowText text={ONCHAIN.liveUrl} fontSize={34} color={COLORS.accentBright} delay={120} fontFamily={MONO} fontWeight={700} />
        <GlowText
          text={`${ONCHAIN.repo} · built for the Somnia Agentathon`}
          fontSize={20}
          color={COLORS.muted}
          delay={140}
          fontWeight={500}
          style={{ marginTop: 16 }}
        />
      </AbsoluteFill>

      <AbsoluteFill style={{ background: "#000", opacity: fadeToBlack }} />
    </AbsoluteFill>
  );
};
