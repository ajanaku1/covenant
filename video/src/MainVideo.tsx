import React from "react";
import { AbsoluteFill, Audio, staticFile, interpolate } from "remotion";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { COLORS, CROSSFADE, FPS, AUDIO_DURATIONS, SCENE_DURATIONS, AUDIO_FILES } from "./constants";
import { Subtitles, SUBS } from "./Subtitles";
import { Hook } from "./scenes/Hook";
import { Problem } from "./scenes/Problem";
import { Authoring } from "./scenes/Authoring";
import { Loop } from "./scenes/Loop";
import { OnChain } from "./scenes/OnChain";
import { Settlement } from "./scenes/Settlement";
import { Close } from "./scenes/Close";

const SceneAudio: React.FC<{ src: string; audioDuration: number }> = ({ src, audioDuration }) => (
  <Audio
    src={staticFile(src)}
    volume={(f) => {
      const fadeIn = interpolate(f, [0, Math.round(FPS * 0.3)], [0, 1], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      });
      const fadeOut = interpolate(f, [audioDuration - FPS, audioDuration], [1, 0], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      });
      return Math.min(fadeIn, fadeOut);
    }}
  />
);

const scenes = [
  { id: "hook" as const, Component: Hook },
  { id: "problem" as const, Component: Problem },
  { id: "authoring" as const, Component: Authoring },
  { id: "loop" as const, Component: Loop },
  { id: "onchain" as const, Component: OnChain },
  { id: "settlement" as const, Component: Settlement },
  { id: "close" as const, Component: Close },
];

export const MainVideo: React.FC = () => {
  const transition = linearTiming({ durationInFrames: CROSSFADE });
  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.bg }}>
      <TransitionSeries>
        {scenes.flatMap((scene, i) => {
          const elements = [
            <TransitionSeries.Sequence key={scene.id} durationInFrames={SCENE_DURATIONS[scene.id]}>
              <scene.Component />
              <Subtitles scene={scene.id as keyof typeof SUBS} />
              <SceneAudio src={AUDIO_FILES[scene.id]} audioDuration={AUDIO_DURATIONS[scene.id]} />
            </TransitionSeries.Sequence>,
          ];
          if (i < scenes.length - 1) {
            elements.push(
              <TransitionSeries.Transition key={`t-${scene.id}`} presentation={fade()} timing={transition} />
            );
          }
          return elements;
        })}
      </TransitionSeries>
    </AbsoluteFill>
  );
};
