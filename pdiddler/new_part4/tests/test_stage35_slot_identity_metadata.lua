-- Stage35 sanitization tests: no raw GUI values, no item copy transfers.
local dir=arg[1] or "pdiddler/new_part4"
package.path=dir.."/?.lua;"..package.path
local M=require("p4_stage35_slot_identity_metadata")
local passed=0
local function test(name,fn)
 local ok,why=pcall(fn)
 if not ok then error("FAILED "..name..": "..tostring(why)) end
 passed=passed+1
end
local function sample()
 return {side="TheirOffer",index=1,slotVisible=true,
  itemNameLabelPresent=true,metadataTruncated=false,
  attributes={},valueNodes={},imageNodes={}}
end
local function failAuthority(r)
 assert(r.tradeOutcome=="UNKNOWN" and r.serverAttestation==false)
 assert(r.serverCompletionProven==false and r.causalAttributionProven==false)
 assert(r.authorizesAccept==false and r.authorizesTrade==false)
 assert(r.mayRecordCompletedTrade==false and r.mayReportProfit==false)
 assert(r.exactItemIdentityConfirmed==false and r.rawIdAuthenticated==false)
 assert(r.readOnly==true)
 assert(r.itemId==nil and r.weaponName==nil and r.accountId==nil)
 assert(r.partnerId==nil and r.rawAttributes==nil and r.assetId==nil)
end
test("no populated slot is incomplete and no completion authority",function()
 local r=M.report(nil)
 assert(r.status=="INCOMPLETE" and not r.slotLocated)
 failAuthority(r)
end)
test("native slot shape only is observed without item identity",function()
 local r=M.report(sample())
 assert(r.status=="SLOT_METADATA_SHAPE_OBSERVED")
 assert(r.slotLocated and r.offerSide=="TheirOffer" and r.slotIndex==1)
 assert(not r.candidateIdFieldPresent and not r.filledImageNodePresent)
 failAuthority(r)
end)
test("metadata names and presence never include hidden raw values",function()
 local s=sample()
 s.attributes={{path="ItemId",valueType="string",nonempty=true,
  value="secret WeaponID alpha:11"}}
 s.valueNodes={{path="Container.WeaponID",valueType="string",
  nonempty=true,value="private partner"}}
 s.imageNodes={{path="IconFrame.Icon",kind="ImageLabel",
  nonempty=true,spriteRect=true,image="rbxassetid://999999999"}}
 local r=M.report(s)
 assert(r.status=="SLOT_METADATA_SHAPE_OBSERVED")
 assert(r.candidateIdFieldPresent and r.filledImageNodePresent)
 assert(r.attributeCandidates[1].path=="ItemId")
 assert(r.candidateValueNodes[1].path=="Container.WeaponID")
 assert(r.imageNodes[1].spriteRect==true)
 assert(r.attributeCandidates[1].value==nil)
 assert(r.candidateValueNodes[1].value==nil)
 assert(r.imageNodes[1].image==nil)
 failAuthority(r)
end)
test("leaf ID in nested node attribute also appears as candidate",function()
 local s=sample()
 s.attributes={{path="SlotData.ItemID",valueType="number",nonempty=true}}
 local r=M.report(s)
 assert(r.candidateIdFieldPresent==true and #r.attributeCandidates==1)
 failAuthority(r)
end)
test("decorative GridSize is not an item ID candidate",function()
 local s=sample()
 s.attributes={{path="Decoration.GridSize",valueType="number",nonempty=true},
   {path="SlotData.ItemName",valueType="string",nonempty=true}}
 local r=M.report(s)
 assert(#r.attributeCandidates==1)
 assert(r.attributeCandidates[1].path=="SlotData.ItemName")
 assert(r.candidateIdFieldPresent==false)
 failAuthority(r)
end)
test("image asset presence alone is not exact weapon identity",function()
 local s=sample()
 s.imageNodes={{path="ItemPicture",kind="ImageLabel",
   nonempty=true,spriteRect=false}}
 local r=M.report(s)
 assert(r.filledImageNodePresent and not r.candidateIdFieldPresent)
 failAuthority(r)
end)
test("empty image cannot indicate useful image metadata",function()
 local s=sample()
 s.imageNodes={{path="ItemPicture",kind="ImageButton",
   nonempty=false,spriteRect=true}}
 local r=M.report(s)
 assert(not r.filledImageNodePresent)
 failAuthority(r)
end)
test("unverified side or slot fails closed",function()
 for _,side in ipairs({"SomeOtherOffer","TheirName",""}) do
  local s=sample();s.side=side
  local r=M.report(s)
  assert(r.status=="INCOMPLETE")
  failAuthority(r)
 end
 local s=sample();s.index=5
 assert(M.report(s).status=="INCOMPLETE")
end)
test("hidden GUI slot fails closed",function()
 local s=sample();s.slotVisible=false
 local r=M.report(s)
 assert(r.status=="INCOMPLETE")
 failAuthority(r)
end)
test("metadata truncation blocks false claim that ID absent",function()
 local s=sample();s.metadataTruncated=true
 local r=M.report(s)
 assert(r.status=="INCOMPLETE" and
    r.reason=="native-slot-metadata-truncated")
 failAuthority(r)
end)
test("metadata structures larger than bound are rejected",function()
 local s=sample()
 for i=1,181 do
  s.attributes[i]={path="ItemId",valueType="string",nonempty=true}
 end
 local r=M.report(s)
 assert(r.status=="INCOMPLETE")
 failAuthority(r)
end)
test("unsafe path or raw player data never enters report",function()
 local s=sample()
 s.attributes={{path="bad name",valueType="string",nonempty=true},
   {path="User_1234",valueType="string",nonempty=true},
   {path="ItemId",valueType="userdata",nonempty=true},
   {path="WeaponKey",valueType="string",nonempty=true}}
 s.valueNodes={{path="Player.ILoveYou:abc",valueType="string",
    nonempty=true},
   {path="Child.WeaponID",valueType="string",nonempty=false}}
 local r=M.report(s)
 assert(#r.attributeCandidates==1)
 assert(r.attributeCandidates[1].path=="WeaponKey")
 assert(#r.candidateValueNodes==1)
 assert(r.candidateValueNodes[1].path=="Child.WeaponID")
 failAuthority(r)
end)
test("report never authorizes settlement even when an ID candidate exists",function()
 local s=sample()
 s.attributes={{path="ItemID",valueType="number",nonempty=true}}
 s.imageNodes={{path="Icon",kind="ImageLabel",
  nonempty=true,spriteRect=true}}
 local r=M.report(s)
 assert(r.candidateIdFieldPresent and r.filledImageNodePresent)
 assert(r.reason=="structural-candidates-only-not-identity-proof")
 failAuthority(r)
end)
print("PASS",passed,"Stage35 pure trade slot metadata shape census")
