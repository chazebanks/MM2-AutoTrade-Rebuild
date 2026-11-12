-- STEP2 isolated public-lobby gate, forked from reviewed System1 test gate.
-- Primary correction: Roblox Players service is userdata, not Lua table.
-- System1 public-lobby consenting-operator target gate (TEST-ONLY).
-- Identifies up to three DISTINCT, currently eligible public lobby players.
-- Does not contact, click, offer, trade, teleport, or Accept. P3 remains
-- the only authority for outgoing requests and their processed ledger.
-- Explicit ARM and stable exact Player-object identity required.
local M={}
local function userid(p)
 -- Roblox Player Instances are userdata, while Lune mocks are tables.
 if type(p)~="userdata" and type(p)~="table" then return nil end
 local ok,n=pcall(function()return p.UserId end)
 return ok and type(n)=="number" and n==math.floor(n) and n>0 and n or nil
end
function M.new(scanner,players,me,options)
 if type(scanner)~="table" or
  (type(players)~="table" and type(players)~="userdata")
  or type(players.GetPlayerByUserId)~="function"
  or type(scanner.getWhitelist)~="function"
  or type(scanner.isWhitelisted)~="function"
  or type(scanner.getRecord)~="function"
  or type(scanner.getOwnInventory)~="function"
  or type(scanner.setRequestState)~="function"
  or type(scanner.setStatus)~="function"
  or type(scanner.hasPendingWork)~="function"
  or type(options)~="table" or options.publicLobbyTest~=true
  or options.noFinalAccept~=true or options.noItemOffers~=true
  or options.noServerHop~=true
  or options.explicitOperatorArm~=true
  or options.maxTargets~=3 or not userid(me) then
  return nil,"PUBLIC_TEST_CONSENT_OR_DEPENDENCY_MISSING"
 end
 local frozen={}
 local armed=false
 local unsafe=nil
 local function exact(p)
  if not userid(p) or p==me or
   p.UserId==me.UserId or p.Parent~=players then return false end
  local ok,a=pcall(players.GetPlayerByUserId,players,p.UserId)
  if not ok or a~=p then return false end
  local good,r=pcall(scanner.getRecord,p.UserId)
  local eligible,yes=pcall(scanner.isWhitelisted,p.UserId)
  return good and type(r)=="table" and
   r.state=="whitelist" and r.player==p and
   eligible and yes==true
 end
 local function snapshot()
  if armed or unsafe then return false,"PUBLIC_TEST_ALREADY_ARMED_OR_STOPPED" end
  local ok,list=pcall(scanner.getWhitelist)
  if not ok or type(list)~="table" then
   return false,"WHITELIST_UNAVAILABLE"
  end
  local all,seen={},{}
  for _,p in ipairs(list) do
   local id=userid(p)
   if id and not seen[id] then
    seen[id]=true
    if exact(p) then all[#all+1]=p end
   elseif id then
    -- Duplicated player IDs in a source list cannot be accepted.
    unsafe="DUPLICATE_SCANNER_USER_ID"
    return false,unsafe
   end
  end
  table.sort(all,function(a,b)return a.UserId<b.UserId end)
  if #all<2 then return false,"NEED_TWO_DISTINCT_VERIFIED_ELIGIBLE_PLAYERS" end
  for i=1,math.min(#all,options.maxTargets) do
   frozen[all[i].UserId]=all[i]
  end
  armed=true
  return true,"PUBLIC_TARGET_SNAPSHOT_ARMED_CLIENT_ONLY"
 end
 local function inspect(id)
  if not armed or unsafe then return nil end
  local p=frozen[id]
  if not p then return nil end
  local ok,current=pcall(players.GetPlayerByUserId,players,id)
  if not ok or (current~=p and current~=nil) then
   unsafe="PUBLIC_PLAYER_OBJECT_REPLACED"
   return nil
  end
  -- Left players may be skipped; never use a stale object.
  if current==nil or p.Parent~=players then return nil end
  local good,record=pcall(scanner.getRecord,id)
  local good2,eligible=pcall(scanner.isWhitelisted,id)
  if not good or not good2 then
   unsafe="PUBLIC_SCANNER_UNREADABLE"
   return nil
  end
  if record~=nil and type(record)=="table" and
      record.player~=nil and record.player~=p then
   unsafe="PUBLIC_SCANNER_PLAYER_MISMATCH"
   return nil
  end
  if not eligible or type(record)~="table" or
      record.state~="whitelist" or record.player~=p then
   return nil -- a real eligibility change is not a reason to contact player
  end
  return p,record
 end
 local wrapper={}
 function wrapper.getWhitelist()
  if not armed or unsafe then return {} end
  local ids={}
  for id in pairs(frozen) do ids[#ids+1]=id end
  table.sort(ids)
  local result={}
  for _,id in ipairs(ids) do
   local p=inspect(id)
   if unsafe then return {} end
   if p then result[#result+1]=p end
  end
  return result
 end
 function wrapper.isWhitelisted(id)
  return inspect(id)~=nil
 end
 function wrapper.getRecord(id)
  local _,record=inspect(id)
  return record
 end
 function wrapper.hasPendingWork()
  if unsafe or not armed then return true end
  local ok,yes=pcall(scanner.hasPendingWork)
  return not ok or yes~=false
 end
 function wrapper.setStatus(...)
  return scanner.setStatus(...)
 end
 function wrapper.setRequestState(p,...)
  if not p or frozen[p.UserId]~=p or unsafe then return end
  return scanner.setRequestState(p,...)
 end
 function wrapper.getOwnInventory()
  return scanner.getOwnInventory()
 end
 local gate={}
 gate.scanner=wrapper
 gate.arm=snapshot
 function gate.status(processed)
  local total,done=0,0
  for id in pairs(frozen) do
   total+=1
   if type(processed)=="table" and processed[id]~=nil then
    done+=1
   end
  end
  return {
   status=unsafe and "STOPPED" or armed and
      (total>0 and done==total and "EXHAUSTED" or "ARMED") or "PREPARING",
   reason=unsafe or "PUBLIC_P3_REQUESTS_ONLY",
   frozenTargets=total,
   processedTargets=done,
   maxContactAttempts=options.maxTargets,
   noFinalAccept=true,noItemOffers=true,noServerHop=true,
   authorizesTrade=false,authorizesOffer=false,
   authorizesAccept=false,serverCompletionProven=false,
  }
 end
 function gate.stop()
  unsafe=unsafe or "OPERATOR_STOPPED"
  return true
 end
 return gate,nil
end
return M
