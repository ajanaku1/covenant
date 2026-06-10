"use client";

import { useMemo, useState } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { parseEther } from "viem";
import { Header } from "@/components/Header";
import { Watch } from "@/components/Watch";
import { parseAgreement, type Scaffold } from "@/lib/parseAgreement";
import { COVENANT_ADDRESS, covenantAbi } from "@/lib/covenant";
import { formatAmount, relativeDuration, shortenAddr } from "@/lib/format";
import { DEMO_PAYEE } from "@/lib/demo";

const SAMPLE =
  "Pay the freelancer 200 USDC when the site at https://acme.build is live and mentions Somnia. Check daily for 7 days. Refund me if it isn't met by the deadline.";

export default function Page() {
  const [text, setText] = useState(SAMPLE);
  const [scaffold, setScaffold] = useState<Scaffold | null>(null);
  const [payee, setPayee] = useState<string>(DEMO_PAYEE);

  const { isConnected } = useAccount();
  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const canDeploy = useMemo(
    () => Boolean(COVENANT_ADDRESS) && isConnected && /^0x[a-fA-F0-9]{40}$/.test(payee),
    [isConnected, payee],
  );

  function handleRead() {
    setScaffold(parseAgreement(text));
  }

  function handleCreate() {
    if (!scaffold || !COVENANT_ADDRESS) return;
    const m = scaffold.milestone;
    const now = Math.floor(Date.now() / 1000);
    const checkAt = now + 120; // first wake ~2 min out (demo-friendly)
    const deadline = now + Math.max(m.durationSeconds, 600);
    const value = parseEther(String(m.payoutAmount || 0));

    writeContract({
      address: COVENANT_ADDRESS,
      abi: covenantAbi,
      functionName: "createAgreement",
      args: [
        payee as `0x${string}`,
        [
          {
            clause: m.clause,
            dataSource: m.dataSource,
            checkAt: BigInt(checkAt),
            deadline: BigInt(deadline),
            checkInterval: BigInt(m.intervalSeconds),
            payout: value,
            passThreshold: m.passThreshold,
            subSize: m.subSize,
            threshold: m.threshold,
          },
        ],
      ],
      value,
    });
  }

  return (
    <>
      <Header />

      <main className="wrap">
        <section className="hero">
          <span className="eyebrow">✦ autonomous agreements on Somnia</span>
          <h1>Write it in English. It enforces itself.</h1>
          <p>
            Describe a deal in a sentence. Covenant holds the escrow, wakes itself on schedule, reads
            the real world with an on-chain LLM panel, and pays out or refunds — no keeper, no oracle,
            no human.
          </p>
        </section>

        {/* Screen 1 — authoring */}
        <div className="section">
          <p className="section-label">Write your agreement</p>
          <div className="card lift composer">
            <textarea
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder="e.g. Pay the freelancer 200 USDC when the site at https://… is live and mentions Somnia. Check daily for 7 days. Refund me if it isn't met."
              spellCheck={false}
            />
            <div className="composer-bar">
              <span className="hint">Plain English. Covenant turns it into an enforceable scaffold.</span>
              <button className="btn btn-primary" onClick={handleRead} disabled={!text.trim()}>
                Read it →
              </button>
            </div>
          </div>

          {scaffold && (
            <div className="reply">
              <div className="assistant-avatar">✦</div>
              <div className="reply-body">
                <p className="reply-lead">
                  Got it — here’s the agreement I’ll enforce. Everything’s editable before you fund it.
                </p>

                <div className="scaffold">
                  <div className="field-row">
                    <span className="chip">
                      <span className="k">Funder</span>
                      <span className="v">you</span>
                    </span>
                    <span className="chip mono">
                      <span className="k">Payee</span>
                      <span className="v">{shortenAddr(payee)}</span>
                    </span>
                    <span className="chip">
                      <span className="k">Escrow</span>
                      <span className="v">{formatAmount(scaffold.totalAmount, scaffold.asset)}</span>
                    </span>
                  </div>

                  <div className="milestone-card">
                    <p className="clause">“{scaffold.milestone.clause}”</p>
                    <div className="kv-grid">
                      <div className="kv">
                        <div className="k">Evidence it reads</div>
                        <div className="v">{scaffold.milestone.dataSource || "—"}</div>
                      </div>
                      <div className="kv">
                        <div className="k">When it checks</div>
                        <div className="v">
                          {scaffold.milestone.intervalLabel} <small>for {scaffold.milestone.durationLabel}</small>
                        </div>
                      </div>
                      <div className="kv">
                        <div className="k">Deadline</div>
                        <div className="v">
                          in {relativeDuration(scaffold.milestone.durationSeconds)}{" "}
                          <small>{scaffold.refundOnDeadline ? "· refund if unmet" : ""}</small>
                        </div>
                      </div>
                      <div className="kv">
                        <div className="k">Payout</div>
                        <div className="v">{formatAmount(scaffold.milestone.payoutAmount, scaffold.asset)}</div>
                      </div>
                      <div className="kv">
                        <div className="k">How sure it must be</div>
                        <div className="v">
                          {scaffold.milestone.passThreshold}/100 <small>median score</small>
                        </div>
                      </div>
                      <div className="kv">
                        <div className="k">Who judges</div>
                        <div className="v">
                          {scaffold.milestone.subSize}-validator panel <small>· {scaffold.milestone.threshold} must agree</small>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="field-row" style={{ alignItems: "center" }}>
                    <input
                      className="chip"
                      style={{ fontFamily: "inherit", minWidth: 320, outline: "none" }}
                      value={payee}
                      onChange={(e) => setPayee(e.target.value)}
                      placeholder="Payee address 0x…"
                      spellCheck={false}
                    />
                  </div>
                </div>

                <div className="note">
                  <span>↘</span>
                  <span>
                    Next: you fund the escrow once. After that Covenant runs on its own — it schedules
                    the daily checks, reads <b>{scaffold.milestone.dataSource || "the source"}</b>, and
                    releases <b>{formatAmount(scaffold.milestone.payoutAmount, scaffold.asset)}</b> the
                    moment the panel agrees the clause is met (or refunds you at the deadline).
                  </span>
                </div>

                <div style={{ display: "flex", gap: 12, alignItems: "center", marginTop: 18, flexWrap: "wrap" }}>
                  <button className="btn btn-primary" onClick={handleCreate} disabled={!canDeploy || isPending || confirming}>
                    {isPending || confirming ? "Funding…" : "Create & fund"}
                  </button>
                  {!COVENANT_ADDRESS && (
                    <span className="hint">Set NEXT_PUBLIC_COVENANT_ADDRESS to fund on testnet. Preview below ↓</span>
                  )}
                  {COVENANT_ADDRESS && !isConnected && <span className="hint">Connect a wallet to fund.</span>}
                  {isSuccess && <span className="badge-auto">✓ Funded · now autonomous</span>}
                  {error && <span className="hint" style={{ color: "var(--red)" }}>Couldn’t fund — check the amount & network.</span>}
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="divider-screen">Once funded · it runs itself</div>

        {/* Screen 2 — watch */}
        <Watch />

        <footer className="footer">
          Covenant · a singleton escrow contract on{" "}
          <a href="https://somnia.network" target="_blank" rel="noreferrer">
            Somnia
          </a>{" "}
          · wakes itself, reads the world, pays out.
        </footer>
      </main>
    </>
  );
}
