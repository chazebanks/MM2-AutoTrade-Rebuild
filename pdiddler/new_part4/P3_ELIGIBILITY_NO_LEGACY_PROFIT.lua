-- Replacement P3 request *eligibility* adapter; no old +15 economic gating.
-- READINESS ONLY: 'reachable' means verified eligible counterparties exist,
-- NOT that an acceptable trade, profit, or quote is available.
local M={}
local function int(n)
 return type(n)=="number" and n==n and n~=math.huge and n>=0 and n==math.floor(n)
end
local function counts(inv)
 if type(inv)~="table" or type(inv.items)~="table" then return nil,"inventory-missing" end
 if type(inv.fingerprint)~="string" or inv.fingerprint=="" then return nil,"inventory-fingerprint-missing" end
 for _,key in ipairs({"unmapped","badQty","unpriced"}) do
  if not int(inv[key]) or inv[key]~=0 then return nil,"inventory-coverage-unknown" end
 end
 local n=#inv.items
 local entries=0
 local seen={}
 for k,it in pairs(inv.items) do
  if not int(k) or k<1 or k>n or type(it)~="table" then return nil,"inventory-array-malformed" end
  entries=entries+1
  local identity=tostring(it.page or "")..":"..tostring(it.checkerId or "")
  if not (it.page=="godly" or it.page=="chroma" or it.page=="ancient")
     or type(it.checkerId)~="string" or not it.checkerId:match("^%d+$")
     or type(it.id)~="string" or it.id==""
     or seen[identity] or not int(it.qty) or it.qty<1
     or it.cat~="Weapons" or not (it.type=="Knife" or it.type=="Gun")
     or type(it.value)~="number" or not (it.value>0 and it.value<math.huge) then
       return nil,"inventory-identity-or-value-unverified"
  end
  seen[identity]=true
 end
 if entries~=n then return nil,"inventory-array-sparse" end
 return inv
end
function M.validateInventory(inv,profile,strict)
 if type(profile)~="table" or type(profile.isFresh)~="function" then return nil,"profile-missing" end
 local fresh,ok=pcall(profile.isFresh)
 if not fresh or ok~=true then return nil,"source-expired" end
 if type(strict)~="table" or type(strict.reprice)~="function" then return nil,"repricer-missing" end
 local checked,why=counts(inv)
 if not checked then return nil,why end
 local okay,result,issue=pcall(strict.reprice,inv,profile)
 if not okay or issue or type(result)~="table" then return nil,"repricing-unverified" end
 local priced,why2=counts(result)
 if not priced or #priced.items~=#inv.items then return nil,why2 or "repriced-count-mismatch" end
 for i,original in ipairs(inv.items) do
  local new=result.items[i]
  if type(new)~="table" or original.id~=new.id or original.page~=new.page
    or original.checkerId~=new.checkerId or original.qty~=new.qty
    or original.name~=new.name then
   return nil,"repricing-identity-mismatch"
  end
 end
 return priced
end
function M.evaluate(own,opponent,profile,strict)
 local a,why=M.validateInventory(own,profile,strict)
 if not a then return "unknown",why end
 local b,why2=M.validateInventory(opponent,profile,strict)
 if not b then return "unknown",why2 end
 if #a.items==0 or #b.items==0 then return "unprofitable","no-eligible-weapons" end
 -- No legacy profit planner, trading decision, or numeric floor; this only permits
 -- P3 to request a conversation. New Part4 decides nothing automatically yet.
 return "reachable","both-inventories-verified;new-strategy-review-required",{
   reviewed=false,authorizesTrade=false,authorizesAccept=false,
   ownFingerprint=a.fingerprint,theirFingerprint=b.fingerprint
 }
end
return M
