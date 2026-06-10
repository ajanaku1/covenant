import type { MilestoneState } from "@/lib/covenant";

const COPY: Record<MilestoneState, string> = {
  Pending: "Pending",
  Checking: "Checking…",
  Met: "Met",
  Refunded: "Refunded",
};

export function StateChip({ state }: { state: MilestoneState }) {
  return (
    <span className={`state ${state.toLowerCase()}`}>
      <span className="pip" />
      {COPY[state]}
    </span>
  );
}
