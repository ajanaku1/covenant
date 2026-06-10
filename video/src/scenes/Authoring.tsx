import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  spring,
  interpolate,
  staticFile,
  OffthreadVideo,
} from "remotion";
import { COLORS } from "../constants";
import { INTER } from "../fonts";
import { AnimatedBackground } from "../components/AnimatedBackground";
import { GlowText } from "../components/GlowText";

const CALLOUTS = [
  { text: "Plain English. No Solidity.", enterFrame: 130, top: 210, left: 130 },
  { text: "Covenant extracts the scaffold", enterFrame: 300, top: 420, left: 1380 },
  { text: "Fund once — the last tx ever sent", enterFrame: 470, top: 760, left: 200 },
];

export const Authoring: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleOut = interpolate(frame, [42, 60], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const videoIn = interpolate(frame, [48, 66], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ background: COLORS.bg }}>
      <AnimatedBackground />

      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", opacity: titleOut }}>
        <GlowText text="Write it. Fund it. Done." fontSize={64} color={COLORS.white} delay={5} />
      </AbsoluteFill>

      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center", opacity: videoIn }}>
        <div
          style={{
            width: 1600,
            borderRadius: 16,
            overflow: "hidden",
            border: `1px solid ${COLORS.border}`,
            boxShadow: `0 0 60px ${COLORS.accent}25`,
          }}
        >
          {frame >= 48 && (
            <OffthreadVideo
              src={staticFile("assets/authoring.mp4")}
              style={{ width: 1600, display: "block" }}
              muted
            />
          )}
        </div>
      </AbsoluteFill>

      {CALLOUTS.map((c, i) => {
        const prog = spring({ frame: frame - c.enterFrame, fps, config: { damping: 14, stiffness: 80 } });
        const nextEnter = CALLOUTS[i + 1]?.enterFrame ?? 9999;
        const fadeOut = interpolate(frame, [nextEnter - 12, nextEnter + 4], [1, 0], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
        const op = interpolate(prog, [0, 0.4], [0, 1], { extrapolateRight: "clamp" }) * fadeOut;
        const scale = interpolate(prog, [0, 1], [0.93, 1]);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              top: c.top,
              left: c.left,
              opacity: op,
              transform: `scale(${scale})`,
              background: `${COLORS.bg}e0`,
              border: `2px solid ${COLORS.accent}`,
              borderRadius: 12,
              padding: "12px 22px",
              backdropFilter: "blur(8px)",
              zIndex: 10,
            }}
          >
            <div style={{ fontFamily: INTER, fontSize: 22, fontWeight: 700, color: COLORS.accentBright }}>
              {c.text}
            </div>
          </div>
        );
      })}
    </AbsoluteFill>
  );
};
