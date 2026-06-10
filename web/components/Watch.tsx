"use client";

import { RECEIPT_BASE } from "@/lib/chain";
import { demoChecks, demoMilestone, DEMO_PAYEE } from "@/lib/demo";
import { shortenAddr } from "@/lib/format";
import { StateChip } from "./StateChip";

function ReceiptLink({ id }: { id: string }) {
  return (
    <a className="receipt-link" href={`${RECEIPT_BASE}/${id}`} target="_blank" rel="noreferrer">
      see the receipt ↗
    </a>
  );
}

/// The calm "watch" view. Reads the bundled demo agreement; once a contract is deployed this is wired
/// to getAgreement/getMilestone + the JudgmentRecorded/MilestoneReleased event log.
export function Watch() {
  const m = demoMilestone;
  return (
    <section className="section" id="watch">
      <div className="card lift">
        <div className="watch-head">
          <h2>Watching — checks run automatically</h2>
          <StateChip state={m.state} />
        </div>
        <p className="reply-lead" style={{ margin: "2px 0 0" }}>
          Paying <b>{shortenAddr(DEMO_PAYEE)}</b> when the site is live and mentions Somnia. You don’t
          send anything — Covenant wakes itself each day and rules on the clause.
        </p>

        <div className="escrow-row">
          <div className="stat">
            <div className="label">Escrow held</div>
            <div className="value">200 USDC</div>
            <div className="sub">reserved · untouchable for gas</div>
          </div>
          <div className="stat">
            <div className="label">Consensus panel</div>
            <div className="value">5 validators</div>
            <div className="sub">median ≥ {m.passThreshold} to pass · {m.threshold} must agree</div>
          </div>
          <div className="stat">
            <div className="label">Since you funded it</div>
            <div className="value">0 txns</div>
            <div className="sub">it runs itself</div>
          </div>
        </div>

        <ul className="timeline">
          {demoChecks.map((c) => {
            const dotClass =
              c.outcome === "checked-met" ? "met" : c.outcome === "checking" ? "checking" : c.outcome === "pending" ? "" : "unmet";
            return (
              <li key={c.day}>
                <div className="tl-marker">
                  <span className={`tl-dot ${dotClass}`} />
                </div>
                <div className="tl-body">
                  <div className="tl-title">
                    {c.label}
                    {c.outcome === "pending" && " · scheduled"}
                    {c.outcome === "checking" && " · panel reading evidence…"}
                    {c.outcome === "checked-unmet" && " · checked · not live yet"}
                    {c.outcome === "checked-met" && " · checked · clause satisfied → released ✓"}
                  </div>
                  <div className="tl-meta">
                    {typeof c.score === "number" && (
                      <span>
                        panel scored <span className="score-tag">{c.score}/100</span>
                      </span>
                    )}
                    {c.requestId && <ReceiptLink id={c.requestId} />}
                  </div>
                </div>
              </li>
            );
          })}
        </ul>

        <div className="note" style={{ background: "var(--green-soft)", color: "var(--ink-soft)" }}>
          <span>✓</span>
          <span>
            You haven’t had to do anything — <b>0 transactions since you funded it</b>. Covenant
            scheduled its own wakes, fetched the evidence, and the validator panel ruled on your clause.
          </span>
        </div>
      </div>
    </section>
  );
}
