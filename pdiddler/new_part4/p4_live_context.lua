-- Stage24 read-only bridge: existing Part3 stable scan + existing Supreme
-- profile => Stage16/17 exact canonical evaluation context.
-- No new scanner, new remote, economic policy, approval, Offer, or Accept.
-- Local scanner timestamps show when a stable read was published; they are
-- not independent/cryptographic server attestations.
local M={}
local map={
 ["stable"]="stable",["rising"]="rising",["overpaid for"]="overpaid",
 ["doing well"]="doing_well",["improving"]="improving",
 ["fluctuating"]="fluctuating",["receding"]="receding",
 ["underpaid for"]="underpaid",["decreasing"]="decreasing",
 ["unsafe"]="unsafe"
}
local function int(n,a,b)
 return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
  and n==math.floor(n) and n>=a and n<=b
end
local function now(fn)
 local good,val=pcall(fn)
 if not good or type(val)~="number" or val~=val then return nil end
 return val
end
local function fresh(h)
 local prof=h.profile
 if prof.liveReady~=true or type(prof.isFresh)~="function"
  or type(prof.get)~="function" or
  type(prof.version)~="string" or prof.version=="" then
   return false end
 local wall=now(h.wall)
 if not int(wall,1,9999999999)
  or not int(prof.observedAtEpoch,1,9999999999)
  or not int(prof.expiresAtEpoch,1,9999999999)
  or prof.expiresAtEpoch<=prof.observedAtEpoch
  or wall<prof.observedAtEpoch or wall>=prof.expiresAtEpoch then return false end
 local ok,yes=pcall(prof.isFresh,wall)
 return ok and yes==true
end
local function normalizeName(name)
 return tostring(name or ""):lower()
  :gsub("’","'"):gsub("^%s+",""):gsub("%s+$","")
  :gsub("%s+"," ")
end
local function scanned(inv,profile)
 if type(inv)~="table" or type(inv.items)~="table"
   or type(inv.fingerprint)~="string" or inv.fingerprint==""
   or inv.unmapped~=0 or inv.badQty~=0 or inv.unpriced~=0
   or #inv.items>300 then return nil,"incomplete-or-unfingerprinted-inventory" end
 local stock,raw,market,seen={},{},{},{}
 local n=0
 for _,it in ipairs(inv.items) do
  n=n+1
  if type(it)~="table" or type(it.id)~="string" or it.id==""
   or type(it.page)~="string" or not (
      it.page=="ancient" or it.page=="chroma" or it.page=="godly")
   or type(it.checkerId)~="string"
   or not it.checkerId:match("^%d+$") or #it.checkerId>8
   or type(it.name)~="string" or it.name==""
   or it.cat~="Weapons" or not (it.type=="Gun" or it.type=="Knife")
   or not int(it.qty,1,1000000) then
    return nil,"scanner-item-identity-or-quantity-invalid"
  end
  local key=it.page..":"..it.checkerId..":checker-id"
  if seen[key] then return nil,"duplicate-canonical-checker-id" end
  seen[key]=true
  local ok,price=pcall(profile.get,it.page,it.checkerId)
  if not ok or type(price)~="table" or price.verified~=true
   or tostring(price.page)~=it.page
   or tostring(price.id)~=it.checkerId
   or normalizeName(price.name)~=normalizeName(it.name)
   or not int(price.demand,0,11)
   or type(price.stability)~="string" then
    return nil,"supreme-item-identity-unverified"
  end
  local stability=map[price.stability:lower()]
  if not stability then return nil,"supreme-stability-unknown" end
  local v=price.supremeValue
  if type(v)~="number" or v~=v or v<=0 or v*100~=math.floor(v*100)
      or v*100>1000000000 then
    return nil,"nonfinite-or-unpriced-supreme-value"
  end
  stock[key]=it.qty
  raw[key]={id=it.id,page=it.page,checkerId=it.checkerId,
     name=it.name,cat=it.cat,type=it.type,qty=it.qty}
  market[key]={valueCents=math.floor(v*100),demand=price.demand,
   stability=stability,tradable=true,verified=true}
 end
 if n~=#inv.items then return nil,"sparse-inventory" end
 return {stock=stock,raw=raw,market=market,fingerprint=inv.fingerprint},nil
end
function M.new(cfg)
 assert(type(cfg)=="table" and type(cfg.scanner)=="table"
   and type(cfg.scanner.getOwnInventory)=="function"
   and type(cfg.scanner.getRecord)=="function"
   and type(cfg.scanner.getVerificationState)=="function"
   and type(cfg.profile)=="table"
   and type(cfg.player)=="table" and
   type(cfg.jobId)=="string" and cfg.jobId~=""
   and type(cfg.session)=="string" and cfg.session~=""
   and type(cfg.clock)=="function" and type(cfg.wall)=="function",
   "Stage24 live evidence dependencies missing")
 local age=cfg.maxAgeSeconds or 30
 assert(type(age)=="number" and age>=2 and age<=120,
   "bad scanner evidence age")
 return {scanner=cfg.scanner,profile=cfg.profile,
  player=cfg.player,game=cfg.game,jobId=cfg.jobId,
  session=cfg.session,clock=cfg.clock,wall=cfg.wall,
  age=age,own=nil,ownAt=nil,sourceVersion=nil}
end
local function jobOK(h)
 return h.game and h.game.JobId==h.jobId
   and h.player and h.player.Parent~=nil
end
function M.refreshOwn(h)
 if not jobOK(h) or not fresh(h) then
  h.own=nil;return false,"job-or-market-unavailable" end
 local version=h.profile.version
 local start=now(h.clock)
 if not start then return false,"clock-unavailable" end
 local ok,inv,err=pcall(h.scanner.getOwnInventory)
 local stop=now(h.clock)
 if not ok or err or not stop or stop<start or stop-start>5
   or not jobOK(h) or not fresh(h) or h.profile.version~=version then
    h.own=nil;return false,"own-inventory-read-not-current" end
 local checked,why=scanned(inv,h.profile)
 if not checked then h.own=nil;return false,why end
 h.own=checked;h.ownAt=stop;h.sourceVersion=version
 return true,"own-fresh-read"
end
function M.build(h)
 if not jobOK(h) or not fresh(h) then
  return nil,"market-or-job-stale" end
 local mono=now(h.clock)
 local wall=now(h.wall)
 if not mono or not wall or not int(wall,1,9999999999) then
  return nil,"source-clock-invalid" end
 if not h.own or not h.ownAt or mono<h.ownAt
  or mono-h.ownAt>h.age or h.sourceVersion~=h.profile.version then
  return nil,"own-scan-stale-or-missing" end
 local v=h.scanner.getVerificationState(h.player.UserId)
 local r=h.scanner.getRecord(h.player.UserId)
 if type(v)~="table" or v.player~=h.player
   or v.scanning==true or v.retryScheduled==true
   or type(v.record)~="table" or
   type(r)~="table" or r.player~=h.player
   or r.state~="whitelist"
   or type(v.record.inv)~="table" or type(r.inv)~="table"
   or r.inv.fingerprint~=v.record.inv.fingerprint then
  return nil,"opponent-scanner-state-unverified" end
 local proof=r.scanProof
 local original=v.record.scanProof
 if type(proof)~="table" or type(original)~="table"
   or proof.kind~="local-stable-scan-publication-v1"
   or proof.sequence~=original.sequence
   or not int(proof.sequence,1,1000000000)
   or proof.playerUserId~=h.player.UserId
   or proof.jobId~=h.jobId
   or proof.fingerprint~=r.inv.fingerprint
   or proof.fingerprint~=original.fingerprint
   or type(proof.completedAtMono)~="number"
   or proof.completedAtMono~=original.completedAtMono
   or mono<proof.completedAtMono
   or mono-proof.completedAtMono>h.age then
  return nil,"opponent-scan-age-or-identity-unproven" end
 local their,why=scanned(r.inv,h.profile)
 if not their then return nil,why end
 local before=h.profile.version
 if not jobOK(h) or not fresh(h) or
    h.profile.version~=before or now(h.clock)<mono then
    return nil,"market-or-job-changed-during-validation" end
 local all={}
 for id,p in pairs(h.own.market) do all[id]=p end
 for id,p in pairs(their.market) do
  local ours=all[id]
  if ours and (ours.valueCents~=p.valueCents
    or ours.demand~=p.demand or ours.stability~=p.stability) then
    return nil,"conflicting-item-price-evidence" end
  all[id]=p
 end
 return {session=h.session,now=wall,market={
   sourceId=h.profile.version,verified=true,
   observedAt=h.profile.observedAtEpoch,
   validUntil=h.profile.expiresAtEpoch,items=all
  },ownInventory=h.own.stock,opponentInventory=their.stock,
  rawOwn=h.own.raw,ownFingerprint=h.own.fingerprint,
  opponentFingerprint=their.fingerprint,
  scanProvenance="local-client-stable-read-only",
  opponentScanSequence=proof.sequence},nil
end
return M
