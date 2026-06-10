import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig, spring, interpolate, staticFile, Img } from "remotion";
import { COLORS } from "../constants";
import { INTER, MONO } from "../fonts";
import { AnimatedBackground } from "../components/AnimatedBackground";
import { GlowText } from "../components/GlowText";

// PLACEHOLDER SCENE — swap the static watch.png for assets/settlement.mp4
// (real released-milestone footage) after the redeploy. See DECISIONS.md.
export const Settlement: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const imgIn = interpolate(frame, [10, 35], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const bannerProg = spring({ frame: frame - 250, fps, config: { damping: 14, stiffness: 80 } });
  const bannerOp = interpolate(bannerProg, [0, 0.4], [0, 1], { extrapolateRight: "clamp" });

  const zeroProg = spring({ frame: frame - 330, fps, config: { damping: 12, stiffness: 70 } });
  const zeroOp = interpolate(zeroProg, [0, 0.4], [0, 1], { extrapolateRight: "clamp" });
  const zeroScale = interpolate(zeroProg, [0, 1], [0.93, 1]);

  return (
    <AbsoluteFill style={{ background: COLORS.bg }}>
      <AnimatedBackground />

      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", paddingBottom: 120 }}>
        <div
          style={{
            width: 1380,
            borderRadius: 16,
            overflow: "hidden",
            border: `1px solid ${COLORS.border}`,
            boxShadow: `0 0 60px ${COLORS.teal}20`,
            opacity: imgIn,
          }}
        >
          <Img src={staticFile("assets/watch.png")} style={{ width: 1380, display: "block" }} />
        </div>

        <div
          style={{
            opacity: bannerOp,
            marginTop: -60,
            fontFamily: INTER,
            fontSize: 26,
            fontWeight: 700,
            color: COLORS.bg,
            background: COLORS.teal,
            borderRadius: 12,
            padding: "16px 34px",
            boxShadow: `0 0 40px ${COLORS.teal}60`,
            zIndex: 5,
          }}
        >
          clause satisfied → escrow released to the payee
        </div>
      </AbsoluteFill>

      <AbsoluteFill style={{ justifyContent: "flex-end", alignItems: "center", paddingBottom: 70 }}>
        <div
          style={{
            opacity: zeroOp,
            transform: `scale(${zeroScale})`,
            display: "flex",
            alignItems: "baseline",
            gap: 18,
          }}
        >
          <span style={{ fontFamily: MONO, fontSize: 64, fontWeight: 700, color: COLORS.accentBright, textShadow: `0 0 40px ${COLORS.accent}60` }}>
            0
          </span>
          <GlowText
            text="transactions sent after funding"
            fontSize={32}
            color={COLORS.white}
            delay={335}
            fontWeight={600}
          />
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
