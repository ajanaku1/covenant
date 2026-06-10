# Covenant — Asset Capture Checklist

## Have now
- [x] docs/images/landing.png — hero UI (reused)
- [x] docs/images/watch.png — watch dashboard (reused)
- [ ] assets/authoring.mp4 — playwright recording: type agreement -> "Read it" -> scaffold confirm (1920x1080@30)
- [ ] assets/receipt.png — screenshot of https://agents.testnet.somnia.network/receipts/5358074
- [ ] assets/explorer.png — shannon explorer page for 0x152432d1B863C0A0645D86452a23F9C16077C28A

## Real on-chain data (Real-Only Principle)
- Covenant singleton: 0x152432d1B863C0A0645D86452a23F9C16077C28A (Somnia testnet 50312)
- createAgreement tx: 0x7259c134a3cec8cd2d2ee80a81d945b6ad24b98cfd17681140ebc4f1ac167834
- Stage A consensus receipt: https://agents.testnet.somnia.network/receipts/5358074
- Buffer: 33 STT; escrow walled off via reservedEscrow

## PENDING (after redeploy with wake-routing fix + ~33.5 STT)
- [ ] assets/settlement.mp4 — watch dashboard flipping to "released" with real receipt link
- [ ] Real released-milestone tx hash + new agreement receipt id
- [ ] Updated contract address everywhere (constants.ts ONCHAIN block)
