import React from "react";
import { AbsoluteFill, useCurrentFrame, interpolate, staticFile, Img } from "remotion";
import { COLORS, ONCHAIN } from "../constants";
import { INTER, MONO } from "../fonts";
import { AnimatedBackground } from "../components/AnimatedBackground";
import { GlowText } from "../components/GlowText";
import { GlassCard } from "../components/GlassCard";

const ROWS = [
  { k: "Network", v: ONCHAIN.chain },
  { k: "Covenant singleton", v: ONCHAIN.covenant },
  { k: "Subscription buffer", v: `${ONCHAIN.buffer} — one floor, every agreement` },
  { k: "Escrow", v: "walled off via reservedEscrow — never spent on gas" },
  { k: "createAgreement tx", v: ONCHAIN.createTx },
];

export const OnChain: React.FC = () => {
  const frame = useCurrentFrame();

  // Typewriter on the tx hash row
  const hashChars = Math.max(0, Math.floor((frame - 150) / 1.2));

  const receiptIn = interpolate(frame, [240, 270], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ background: COLORS.bg }}>
      <AnimatedBackground />
      <AbsoluteFill style={{ alignItems: "center", paddingTop: 70 }}>
        <GlowText text="Live on Somnia testnet" fontSize={48} color={COLORS.white} delay={5} />
      </AbsoluteFill>

      <AbsoluteFill style={{ flexDirection: "row", justifyContent: "center", alignItems: "center", gap: 44, paddingTop: 60 }}>
        <GlassCard delay={30} style={{ width: 800, padding: "34px 38px" }}>
          {ROWS.map((r, i) => {
            const op = interpolate(frame, [55 + i * 22, 75 + i * 22], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            });
            const isHash = r.k === "createAgreement tx";
            const value = isHash ? r.v.slice(0, hashChars) : r.v;
            return (
              <div key={r.k} style={{ marginBottom: 22, opacity: op }}>
                <div style={{ fontFamily: INTER, fontSize: 15, fontWeight: 600, color: COLORS.muted, letterSpacing: 2, textTransform: "uppercase", marginBottom: 6 }}>
                  {r.k}
                </div>
                <div style={{ fontFamily: MONO, fontSize: isHash || r.k.includes("singleton") ? 17 : 20, color: isHash ? COLORS.accentBright : COLORS.white, wordBreak: "break-all" }}>
                  {value}
                  {isHash && hashChars > 0 && hashChars < r.v.length && (
                    <span style={{ opacity: Math.sin(frame * 0.3) > 0 ? 1 : 0, color: COLORS.accent }}>_</span>
                  )}
                </div>
              </div>
            );
          })}
        </GlassCard>

        <div style={{ opacity: receiptIn, transform: `scale(${interpolate(receiptIn, [0, 1], [0.97, 1])})` }}>
          <div
            style={{
              width: 760,
              borderRadius: 14,
              overflow: "hidden",
              border: `1px solid ${COLORS.border}`,
              boxShadow: `0 0 50px ${COLORS.accent}20`,
            }}
          >
            <Img src={staticFile("assets/receipt.png")} style={{ width: 760, display: "block" }} />
          </div>
          <div style={{ fontFamily: MONO, fontSize: 17, color: COLORS.teal, marginTop: 14, textAlign: "center" }}>
            real consensus receipt — {ONCHAIN.receiptUrl}
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
