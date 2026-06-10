"use client";

import { useAccount, useConnect, useDisconnect } from "wagmi";
import { injected } from "wagmi/connectors";
import { shortenAddr } from "@/lib/format";

export function Header() {
  const { address, isConnected } = useAccount();
  const { connect } = useConnect();
  const { disconnect } = useDisconnect();

  return (
    <header className="site-header">
      <div className="wrap">
        <div className="wordmark">
          <span className="glyph">✦</span>
          <span>Covenant</span>
        </div>
        {isConnected ? (
          <button className="nav-pill" onClick={() => disconnect()} title="Disconnect">
            <span className="dot" />
            {shortenAddr(address ?? "")}
          </button>
        ) : (
          <button className="nav-pill" onClick={() => connect({ connector: injected() })}>
            Connect wallet
          </button>
        )}
      </div>
    </header>
  );
}
