#!/usr/bin/env bash
# derisk.sh — prove the two risky legs of Covenant on Somnia testnet before building on them.
#
#   Stage A  (agent leg, ~1 STT):  deploy AgentProbe, fire one JSON-API request, watch the
#                                  consensus callback land and print the Agent Explorer receipt.
#   Stage B  (reactivity leg, ~33 STT): deploy ReactiveWatcher, fund the 32-STT buffer, schedule a
#                                  self-wake ~60s out, and confirm the chain invoked it with NO tx.
#
# Usage:
#   cp .env.example .env && edit it          # PRIVATE_KEY must be a funded testnet burner
#   ./script/derisk.sh a                      # Stage A only (cheap; run first)
#   ./script/derisk.sh b                      # Stage B only (needs ~33 STT — request a Discord grant)
#   ./script/derisk.sh all                    # both
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] || { echo "missing .env (copy .env.example)"; exit 1; }
set -a; . ./.env; set +a
: "${PRIVATE_KEY:?set PRIVATE_KEY in .env}"
: "${RPC_URL:?set RPC_URL in .env}"
: "${PLATFORM_ADDRESS:?set PLATFORM_ADDRESS in .env}"

FROM=$(cast wallet address "$PRIVATE_KEY")
echo "deployer: $FROM"
echo "balance:  $(cast balance "$FROM" --rpc-url "$RPC_URL" --ether) STT"
SEND="cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --json"
CALL="cast call --rpc-url $RPC_URL"

deployed() { jq -r '.deployedTo' ; }

stage_a() {
  echo; echo "=== Stage A: agent leg ==="
  PROBE=$(forge create src/AgentProbe.sol:AgentProbe --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" \
            --broadcast --json --constructor-args "$PLATFORM_ADDRESS" | deployed)
  echo "AgentProbe: $PROBE"

  # One numeric fetch over 3 validators, threshold 2. JSON-API agent ~0.03 STT/validator; surplus refunds.
  STAGE_A_VALUE="${STAGE_A_VALUE:-0.2ether}"
  URL="https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd"
  echo "firing probeJsonUint -> $URL (ethereum.usd), value $STAGE_A_VALUE"
  TX=$($SEND "$PROBE" "probeJsonUint(string,string,uint8,uint256,uint256)" \
        "$URL" "ethereum.usd" 8 3 2 --value "$STAGE_A_VALUE" | jq -r '.transactionHash')
  echo "request tx: $TX"

  echo "waiting for consensus callback (up to ~3 min)…"
  for i in $(seq 1 36); do
    sleep 5
    STATUS=$($CALL "$PROBE" "last()(uint256,uint8,uint256,uint256,uint256)" 2>/dev/null | sed -n '2p' || echo 0)
    if [ "${STATUS:-0}" = "2" ]; then
      RAW=$($CALL "$PROBE" "last()(uint256,uint8,uint256,uint256,uint256)")
      RID=$(echo "$RAW" | sed -n '1p'); VAL=$(echo "$RAW" | sed -n '3p'); CNT=$(echo "$RAW" | sed -n '4p')
      echo "✅ Success: requestId=$RID median=$VAL responders=$CNT"
      echo "   receipt: https://agents.testnet.somnia.network/receipts/$RID"
      return 0
    fi
    echo "  …status=$STATUS (poll $i)"
  done
  echo "❌ no Success callback within timeout — inspect tx $TX on the explorer"; return 1
}

stage_b() {
  echo; echo "=== Stage B: reactivity leg ==="
  W=$(forge create src/ReactiveWatcher.sol:ReactiveWatcher --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" \
        --broadcast --json | deployed)
  echo "ReactiveWatcher: $W"

  echo "funding 33 STT buffer (>= 32 STT subscription-owner floor)…"
  $SEND "$W" --value 33ether > /dev/null
  echo "balance: $(cast balance "$W" --rpc-url "$RPC_URL" --ether) STT"

  NOW_MS=$(( $(date +%s) * 1000 ))
  WHEN=$(( NOW_MS + 60000 ))   # ~60s out (scheduler uses millisecond timestamps)
  echo "scheduling self-wake at $WHEN ms (~60s)…"
  $SEND "$W" "scheduleWake(uint256)" "$WHEN" > /dev/null

  echo "waiting for the chain to invoke _onEvent with NO further tx (up to ~3 min)…"
  for i in $(seq 1 36); do
    sleep 5
    CNT=$($CALL "$W" "wakeCount()(uint256)" 2>/dev/null || echo 0)
    if [ "${CNT:-0}" != "0" ]; then
      echo "✅ woke autonomously: wakeCount=$CNT — reactivity confirmed"; return 0
    fi
    echo "  …wakeCount=0 (poll $i)"
  done
  echo "❌ never woke within timeout — check the buffer balance and scheduled timestamp"; return 1
}

case "${1:-all}" in
  a)   stage_a ;;
  b)   stage_b ;;
  all) stage_a; stage_b ;;
  *)   echo "usage: $0 {a|b|all}"; exit 1 ;;
esac
