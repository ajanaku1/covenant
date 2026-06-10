import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring, interpolate } from "remotion";
import { COLORS } from "../constants";
import { INTER, MONO } from "../fonts";
import { AnimatedBackground } from "../components/AnimatedBackground";
import { GlowText } from "../components/GlowText";

export const Hook: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Phase 1 (0-150): the question. Phase 2 (150+): brand reveal.
  const questionOut = interpolate(frame, [140, 165], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const brandIn = spring({ frame: frame - 165, fps, config: { damping: 16, stiffness: 90 } });
  const brandOp = interpolate(brandIn, [0, 0.4], [0, 1], { extrapolateRight: "clamp" });
  const brandScale = interpolate(brandIn, [0, 1], [0.93, 1]);

  return (
    <AbsoluteFill style={{ background: COLORS.bg }}>
      <AnimatedBackground />

      {/* Phase 1: provocative line */}
      <AbsoluteFill
        style={{
          justifyContent: "center",
          alignItems: "center",
          flexDirection: "column",
          opacity: questionOut,
          padding: 120,
        }}
      >
        <GlowText
          text="Every smart contract waits for someone"
          fontSize={58}
          color={COLORS.white}
          delay={8}
          fontWeight={700}
        />
        <GlowText
          text="to push the button."
          fontSize={58}
          color={COLORS.white}
          delay={28}
          fontWeight={700}
          style={{ marginBottom: 48 }}
        />
        <GlowText
          text="What if one needed nobody?"
          fontSize={44}
          color={COLORS.accentBright}
          delay={75}
          fontWeight={600}
          glowIntensity={1.3}
        />
      </AbsoluteFill>

      {/* Phase 2: brand reveal */}
      <AbsoluteFill
        style={{
          justifyContent: "center",
          alignItems: "center",
          flexDirection: "column",
          opacity: brandOp,
          transform: `scale(${brandScale})`,
        }}
      >
        <div
          style={{
            fontFamily: INTER,
            fontSize: 120,
            fontWeight: 900,
            letterSpacing: 6,
            background: `linear-gradient(135deg, ${COLORS.accentBright}, ${COLORS.accent}, ${COLORS.teal})`,
            backgroundClip: "text",
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
          }}
        >
          COVENANT
        </div>
        <GlowText
          text="Agreements that read the world and pay themselves"
          fontSize={32}
          color={COLORS.offWhite}
          delay={185}
          fontWeight={500}
          style={{ marginTop: 12 }}
        />
        <div
          style={{
            marginTop: 44,
            opacity: interpolate(frame, [215, 235], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
            fontFamily: MONO,
            fontSize: 18,
            color: COLORS.accentBright,
            border: `1px solid ${COLORS.border}`,
            borderRadius: 999,
            padding: "10px 26px",
            background: COLORS.bgCard,
          }}
        >
          Built on Somnia — the Agentic L1
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
