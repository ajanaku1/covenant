import React from "react";
import { AbsoluteFill, useCurrentFrame, interpolate } from "remotion";
import { COLORS, SOCIAL_DURATION, ONCHAIN } from "./constants";
import { INTER, MONO } from "./fonts";
import { AnimatedBackground } from "./components/AnimatedBackground";
import { GlowText } from "./components/GlowText";

const VERTICAL_ORBS = [
  { baseX: 200, baseY: 300, size: 400, color: COLORS.accent, blur: 120, opacity: 0.12, speed: 0.006 },
  { baseX: 880, baseY: 1600, size: 360, color: COLORS.accentDim, blur: 110, opacity: 0.1, speed: 0.005 },
  { baseX: 540, baseY: 960, size: 480, color: COLORS.teal, blur: 140, opacity: 0.07, speed: 0.008 },
  { baseX: 100, baseY: 1400, size: 320, color: "#8b5cf6", blur: 100, opacity: 0.07, speed: 0.007 },
];

export const SocialClip: React.FC = () => {
  const frame = useCurrentFrame();
  const dur = SOCIAL_DURATION;

  const exitOp = interpolate(frame, [dur - 20, dur], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ background: COLORS.bg }}>
      <AnimatedBackground orbs={VERTICAL_ORBS} />
      <AbsoluteFill
        style={{
          flexDirection: "column",
          justifyContent: "center",
          alignItems: "center",
          padding: "80px 60px",
          zIndex: 10,
          opacity: exitOp,
        }}
      >
        <GlowText text="0" fontSize={180} color={COLORS.accentBright} delay={5} fontWeight={900} glowIntensity={1.5} fontFamily={MONO} />
        <GlowText
          text="TRANSACTIONS AFTER DEPLOY"
          fontSize={30}
          color={COLORS.offWhite}
          delay={18}
          fontWeight={600}
          style={{ letterSpacing: 4, marginBottom: 90, textAlign: "center" }}
        />
        <div
          style={{
            fontFamily: INTER,
            fontSize: 64,
            fontWeight: 900,
            letterSpacing: 3,
            background: `linear-gradient(135deg, ${COLORS.accentBright}, ${COLORS.accent}, ${COLORS.teal})`,
            backgroundClip: "text",
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
            opacity: interpolate(frame, [35, 55], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            marginBottom: 20,
          }}
        >
          COVENANT
        </div>
        <GlowText
          text="Write a deal in English. It enforces itself."
          fontSize={34}
          color={COLORS.accent}
          delay={55}
          fontWeight={600}
          glowIntensity={0.8}
          style={{ textAlign: "center", marginBottom: 70 }}
        />
        <GlowText
          text={ONCHAIN.liveUrl}
          fontSize={26}
          color={COLORS.muted}
          delay={75}
          fontWeight={500}
          fontFamily={MONO}
          style={{ textAlign: "center" }}
        />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
