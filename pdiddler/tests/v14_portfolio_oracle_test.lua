-- Preserve the complete V12 policy suite; constrain its independent exhaustive
-- enumerator by the user's new prohibition on giving a received canonical item.
local file=assert(io.open('pdiddler/tests/v12_portfolio_ledger_policy_test.lua'))
local source=file:read('*a');file:close()
source=source:gsub('pdiddler4_supreme_policy_v8_PORTFOLIO_LEDGER.lua','pdiddler4_supreme_policy_v9_CONSISTENT_QUOTES.lua')
-- Ledger compatibility continues to exercise E3 separately; E4 has its own
-- changed-behavior tests and production P4 execution in the release gate.
local old='for qty=0,math.min(x.qty,4-units) do'
local replacement=[[local maximum=math.min(x.qty,4-units)
  for _,received in ipairs(incoming) do
   if x.page==received.page and (x.checkerId or x.id)==(received.checkerId or received.id) then maximum=0 end
  end
  for qty=0,maximum do]]
local at=assert(source:find(old,1,true));source=source:sub(1,at-1)..replacement..source:sub(at+#old)
assert(load(source,'v14-independent-exhaustive-oracle','t',_G))()
