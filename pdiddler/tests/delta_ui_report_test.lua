-- Reuse preserved native-boundary fixture, execute the actual successor module.
local file=assert(io.open('pdiddler/tests/delta_ui_audit_test.lua'));local original=file:read('*a');file:close()
local start=assert(original:find("test('dual exact headers",1,true))
local prefix=original:sub(1,start-1):gsub('pdiddler_delta_ui_audit_v1.lua','pdiddler_delta_ui_audit_v2_ASCII.lua')
local cases=[=[
local artifact='/tmp/pdiddler-delta-ui-format-v2.jsonl'
local output=assert(io.open(artifact,'w'));output:close()
local function ascii(s)
 assert(type(s)=='string')
 for i=1,#s do local b=s:byte(i);assert(b>=32 and b<=126,'non-ASCII/control byte '..b..' at '..i) end
end
local function reordered(value)
 if type(value)~='table' then return value end
 local keys={};for k in pairs(value) do keys[#keys+1]=k end
 table.sort(keys,function(a,b) return tostring(a)>tostring(b) end)
 local result={};for _,k in ipairs(keys) do result[k]=reordered(value[k]) end
 return result
end
local function formatted(report,source)
 assert(type(Audit.format)=='function','native-JSON-independent formatter missing')
 local text=Audit.format(report,source);ascii(text)
 local out=assert(io.open(artifact,'a'));out:write(text,'\n');out:close()
 return text
end

test('actual module exposes a deterministic native-JSON-independent formatter',function()
 local f=fixture();f:overlay();local r=f:inspect()
 local a=formatted(r,'fresh-v2');local b=formatted(r,'fresh-v2');local c=formatted(reordered(r),'fresh-v2')
 eq(a,b);eq(a,c);assert(a:find('"traceVersion":2',1,true));assert(a:find('"traceSource":"fresh-v2"',1,true))
 assert(a:find('"traceEncoding":"ascii-byte-escaped"',1,true))
 assert(a:find('"owners":',1,true) and a:find('"controls":',1,true))
 assert(a:find('Roblox Console',1,true) and a:find('Delta Console',1,true) and a:find('Exit',1,true))
end)

for _,case in ipairs({
 {'raw invalid byte',string.char(255),'\\xFF'},
 {'high/control bytes','A'..string.char(1,128,254),'\\x01'},
 {'UTF8 cut at64 bytes',string.rep('a',63)..string.char(195,169),'\\xC3'},
}) do
 test(case[1]..' produces ASCII descriptors without reading private editor content',function()
  local f=fixture();local owner,_,_,button=f:overlay();local secret='PRIVATE-EDITOR-CREDENTIAL'
  f.states[owner].Name=case[2];f.states[button].Name='Exit'..case[2]
  f:node('PrivateEditor','TextBox',owner,{Text=secret})
  f:node('ConsoleBody','TextLabel',owner,{Text=secret})
  local r=f:inspect()
  for _,v in ipairs(r.owners) do ascii(v.name);ascii(v.path) end
  for _,v in ipairs(r.controls) do ascii(v.name);ascii(v.path) end
  assert(strings(r):find(case[3],1,true),'unsafe source byte lost diagnostic representation')
  assert(not strings(r):find(secret,1,true));eq(f.textBoxReads,0)
  local text=formatted(r,'fresh-v2');assert(not text:find(secret,1,true))
 end)
end

test('cached-v1 invalid byte strings are escaped without changing cached data',function()
 local raw='cached'..string.char(255,195)
 local r={status='control-inaccessible',reason='native-exit-contract-unverified',jobId='job-1',visited=4,truncated=false,
  roots={{source='gethui',accessible=true}},labels={{text='Delta Console',ownerId='gui1',visible=true,visibilityKnown=true}},
  owners={{id='gui1',name=raw,path='CoreGui/'..raw,className='ScreenGui'}},
  controls={{ownerId='gui1',name='Exit',path=raw..'/Exit',className='ImageButton',visible=true,visibilityKnown=true,x=9,y=8,width=7,height=6,image='rbxassetid://123'}}}
 local text=formatted(r,'cached-v1')
 eq(r.owners[1].name,raw);eq(r.controls[1].path,raw..'/Exit')
 assert(text:find('"traceSource":"cached-v1"',1,true));assert(text:find('Exit',1,true))
 assert(text:find('\\\\xFF',1,true),'escaped cached byte did not survive JSON quoting')
end)

test('formatter projects known fields and excludes private unknown keys at every level',function()
 local f=fixture();f:overlay();local r=f:inspect();local secret='PRIVATE-WEBHOOK-DO-NOT-PRINT'
 r.Text=secret;r.editorBody=secret;r.webhook=secret;r.unknown={token=secret};r.actions=99;r.closeSupported=true
 r.owners[1].Text=secret;r.controls[1].editorBody=secret;r.labels[1].Text=secret
 local text=formatted(r,'fresh-v2');assert(not text:find(secret,1,true))
 assert(not text:find('editorBody',1,true));assert(not text:find('webhook',1,true))
 assert(text:find('"actions":0',1,true));assert(text:find('"closeSupported":false',1,true))
end)

test('JSON quotes backslashes and controls remain independently parseable',function()
 local f=fixture();local owner,_,_,button=f:overlay()
 f.states[owner].Name='quote" slash\\ newline\n';f.states[button].Name='Exit\\"'
 local r=f:inspect();local text=formatted(r,'fresh-v2')
 assert(text:find('\\"',1,true),'JSON quote was not escaped')
 assert(text:find('\\\\',1,true),'JSON backslash was not escaped')
end)

test('metatable cyclic and live values never trigger methods or private coercion',function()
 local f=fixture();local _,_,_,live=f:overlay();local r=f:inspect();local calls=0
 local trap=setmetatable({}, {
  __index=function() calls=calls+1;error('private __index invoked') end,
  __pairs=function() calls=calls+1;error('private __pairs invoked') end,
  __len=function() calls=calls+1;error('private __len invoked') end,
  __tostring=function() calls=calls+1;error('PRIVATE-LIVE-STRING') end,
 })
 local before=f.totalReads
 formatted(trap,'cached-v1')
 r.unknown=r;r.roots=trap
 r.owners[2]=trap;r.owners[3]={id='gui-safe',name=function() calls=calls+1 end,path=live,className='ScreenGui'}
 r.controls[2]=live;r.controls[3]=trap
 local cyclic={ownerId='gui1',className='ImageButton'};cyclic.name=cyclic;cyclic.path=r
 r.controls[4]=cyclic
 local text=formatted(r,'cached-v1')
 eq(calls,0);eq(f.totalReads,before);eq(f.mutations,0);eq(f.inputs,0)
 assert(not text:find('PRIVATE-LIVE-STRING',1,true));assert(not text:find('"unknown":',1,true))
end)

test('skipped and invalid reports cannot claim that a UI inspection occurred',function()
 local f=fixture();f.env.PDIDDLER_PART4_SESSION=1
 local r=f:inspect();eq(r.status,'skipped')
 assert(formatted(r,'fresh-v2'):find('"inspectionPerformed":false',1,true))
 assert(formatted(nil,'fresh-v2'):find('"inspectionPerformed":false',1,true))
end)

test('cached-v1 trace cannot claim a new inspection or current visible UI proof',function()
 local f=fixture();f:overlay();local r=f:inspect()
 r.inspectionPerformed=true;r.currentVisibilityVerified=true;r.captureTimeKnown=true;r.selectorsVerified=true
 local text=formatted(r,'cached-v1')
 assert(text:find('"inspectionPerformed":false',1,true))
 assert(text:find('"currentVisibilityVerified":false',1,true))
 assert(text:find('"captureTimeKnown":false',1,true));assert(text:find('"selectorsVerified":false',1,true))
 eq(r.inspectionPerformed,true);eq(r.currentVisibilityVerified,true)
end)

test('literal backslash escape-looking names stay distinct from actual high bytes',function()
 local a=fixture();local ao=a:overlay();a.states[ao].Name=string.char(255)
 local b=fixture();local bo=b:overlay();b.states[bo].Name='\\xFF'
 local ar,br=a:inspect(),b:inspect()
 assert(ar.owners[1].name~=br.owners[1].name,'fresh descriptors conflated byte with literal backslash')
 assert(formatted(ar,'fresh-v2')~=formatted(br,'fresh-v2'))
 ar.owners[1].name=string.char(255);br.owners[1].name='\\xFF'
 assert(formatted(ar,'cached-v1')~=formatted(br,'cached-v1'),'cached formatter conflated byte with literal backslash')
end)

test('huge known fields produce bounded valid ASCII JSON with explicit trace truncation',function()
 local huge=string.rep(string.char(255),2048)
 local r={status='control-inaccessible',reason='native-exit-contract-unverified',jobId='job-1',roots={},labels={},owners={},controls={}}
 for i=1,16 do r.owners[i]={id='gui'..i,className='ScreenGui',name=huge,path=huge} end
 local text=formatted(r,'cached-v1')
 assert(#text<=16384,'owner expansion exceeded structured output budget: '..#text)
 assert(text:find('"traceTruncated":true',1,true),'bounded output omitted truncation marker')
end)

print('RESULT '..passed..' report tests passed; '..failed..' failed')
assert(failed==0,'Delta UI report module tests failed')
]=]
assert(load(prefix..cases,'actual-delta-report-v2-tests','t',_G))()
