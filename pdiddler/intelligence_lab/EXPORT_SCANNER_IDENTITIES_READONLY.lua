-- Stage 3: read-only scanner evidence export. Run after existing V15.8 loader.
-- Does NOT send/accept offers, click, hop, or modify Pdiddler.
-- The existing loader, if running, retains its own automated behavior.
local e=(getgenv and getgenv()) or _G
local b=e.PDIDDLER_INTEGRATION_V15_8_VALUE_FIRST
if type(b)~="table" or type(b.rawScanner)~="table"
    or type(b.rawScanner.getOwnInventory)~="function" then
    warn("[PDIDDLER LAB] Main V15.8 scanner not loaded. No export.")
    return
end
local ok,inv,why=pcall(b.rawScanner.getOwnInventory)
if not ok or type(inv)~="table" then
    warn("[PDIDDLER LAB] Own scanner read unavailable:",tostring(ok and why or inv))
    return
end
local out={
    format="pdiddler-scanner-observation-v1",
    source="native_scanner_readonly",
    rawOwned=inv.rawOwned,
    unmapped=inv.unmapped,
    unpriced=inv.unpriced,
    badQty=inv.badQty,
    fingerprint=inv.fingerprint,
    marketVersion=b.profile and b.profile.version or "not-loaded",
    marketFresh=b.profile and type(b.profile.isFresh)=="function" and b.profile.isFresh()==true or false,
    items={}
}
for _,it in ipairs(inv.items or {}) do
    out.items[#out.items+1]={
        id=tostring(it.id or ""),
        checkerId=tostring(it.checkerId or ""),
        page=tostring(it.page or ""),
        name=tostring(it.name or ""),
        cat=tostring(it.cat or ""),
        type=tostring(it.type or ""),
        qty=it.qty,
        year=tostring(it.year or ""),
        event=tostring(it.event or ""),
        value=it.value
    }
end
table.sort(out.items,function(a,c) return a.id<c.id end)
local encoded=game:GetService("HttpService"):JSONEncode(out)
e.PDIDDLER_LAB_SCANNER_EXPORT=encoded
if type(setclipboard)=="function" then
    local copied,copyErr=pcall(setclipboard,encoded)
    if copied then
        print("[PDIDDLER LAB] SUCCESS: scanner JSON copied | priced rows",#out.items,
            "| market fresh",out.marketFresh,"| unmapped",out.unmapped,"| unpriced",out.unpriced)
    else
        warn("[PDIDDLER LAB] Clipboard failed:",tostring(copyErr))
        print(encoded)
    end
else
    print("[PDIDDLER LAB] No clipboard API. JSON follows")
    print(encoded)
end
