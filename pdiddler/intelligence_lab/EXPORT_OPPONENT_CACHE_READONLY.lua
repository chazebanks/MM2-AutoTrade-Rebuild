-- Stage 6: snapshot only scanner's ALREADY-CACHED opponent records.
-- No remotes, trade actions, clicks, waits, hops, or automated suggestions.
-- A cached record has NO timestamp proving when its underlying scan completed.
local E=(getgenv and getgenv()) or _G
local B=E.PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST
if type(B)~="table" or type(B.rawScanner)~="table"
    or type(B.rawScanner.getRecord)~="function"
    or type(B.rawScanner.getVerificationState)~="function" then
    warn("[GINGERSCOPE LAB] V15.8 scanner not loaded; nothing exported")
    return
end
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local job=game.JobId
local roster={}
for _,p in ipairs(Players:GetPlayers()) do
    if p~=Players.LocalPlayer then roster[#roster+1]=p end
end
table.sort(roster,function(a,b) return a.UserId<b.UserId end)
local out={
    format="pdiddler-opponent-cache-v1",source="scanner-record-cache",
    snapshotAtEpoch=os.time(),cacheFreshnessProven=false,
    marketVersion=B.profile and B.profile.version or "not-loaded",
    marketFresh=B.profile and type(B.profile.isFresh)=="function"
        and B.profile.isFresh()==true or false,
    targets={}
}
for i,p in ipairs(roster) do
    local v=B.rawScanner.getVerificationState(p.UserId)
    local rec=B.rawScanner.getRecord(p.UserId)
    local inv=rec and rec.inv or nil
    local target={label="P"..i,
        state=rec and tostring(rec.state or "unknown") or "missing",
        present=v and v.player==p and p.Parent==Players or false,
        scanning=v and v.scanning==true or false,
        retryScheduled=v and v.retryScheduled==true or false,
        fingerprint=inv and tostring(inv.fingerprint or "") or "",
        rawOwned=inv and inv.rawOwned or nil,
        unmapped=inv and inv.unmapped or nil,
        unpriced=inv and inv.unpriced or nil,
        badQty=inv and inv.badQty or nil,items={}}
    for _,it in ipairs((inv and inv.items) or {}) do
        target.items[#target.items+1]={id=tostring(it.id or ""),
            checkerId=tostring(it.checkerId or ""),
            page=tostring(it.page or ""),name=tostring(it.name or ""),
            type=tostring(it.type or ""),cat=tostring(it.cat or ""),
            qty=it.qty,value=it.value}
    end
    table.sort(target.items,function(a,b) return a.id<b.id end)
    out.targets[#out.targets+1]=target
end
if game.JobId~=job then
    warn("[GINGERSCOPE LAB] Server changed during snapshot; export discarded")
    return
end
out.totalTargets=#out.targets
local encoded=HttpService:JSONEncode(out)
E.PDIDDLER_LAB_OPPONENT_EXPORT=encoded
if type(setclipboard)=="function" then
    local ok=pcall(setclipboard,encoded)
    if ok then
        print("[GINGERSCOPE LAB] Cached opponent JSON copied | targets",out.totalTargets,
            "| marketFresh",out.marketFresh,"| cache age UNKNOWN")
        return
    end
end
print("[GINGERSCOPE LAB] Clipboard unavailable; JSON follows:")
for i=1,#encoded,700 do print(encoded:sub(i,i+699)) end
