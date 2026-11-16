-- True original coordinator+P4 TradeIO native synthetic Roblox fixture.
-- Invoked from existing supervised_real_p3_rotation_handoff_mocks.luau.
-- This tests a NEW adapter but does not replace the P3/P4 coordinator.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local M={}
function M.run(deps)
 local factory,bind,accept,eq=deps.fixture,deps.bind,deps.acceptP3,deps.eq
 local a=luau.load(fs.readFile(
  "pdiddler/system2/native_c9_original_p3_protected_host_adapter.lua"))()
 do
  local x=factory()
  x.ctx.job="MAIN_C9_NATIVE_JOB_0001"
  local manager=bind(x)
  local game={PlaceId=142823291,JobId=x.ctx.job,
  GetService=function(_,key)
   if key=="Players" then return x.players end
  end}
  local bound={jobId=x.ctx.job,session="p3stage119:"..tostring(x.ctx.epoch),
   root=x.trade,localPlayer=x.lp,partnerPlayer=x.p}
  local supervisor={
    currentBoundReadOnly=manager.currentBoundReadOnly,
    isP3Paused=x.p3.isPaused,
  }
  local host={supervisor=supervisor,
   readOriginalHostBoundScope=function()return bound end,
   getJobId=x.ctx.getJobId,getP3Session=x.ctx.getP3Session,
   isOriginalHostRunning=function()return true end,
   io=x.io,players=x.players,game=game}
  local nilHost,why=a.new(host)
  eq(nilHost,nil,"C9 cannot bind original coordinator BEFORE P3 original processed outcome")
  eq(why.reason,"ORIGINAL_P3_HOST_TRADE_NOT_PAUSED",
   "C9 pre-arm must fail closed with no P3 requests or offer")
  eq(#x.sends,0,"C9 host never sends original OfferItem remote")
  accept(x)
  local handle,problem=a.new(host)
  eq(type(handle),"table","C9 genuine original coordinator read facade admitted")
  eq(problem,nil,"C9 original protected host contains no construction error")
  eq(handle.scope.jobId,x.ctx.job,"C9 original P3 job retained only locally")
  eq(handle.scope.partnerUserId,x.p.UserId,
   "C9 actual P3 processed user bound, not guessed display name")
  eq(handle.scope.root,x.trade,"C9 P4 GUI root exactly original protected GUI")
  eq(handle.isBoundSession(),true,"C9 revocable lease remains active")
  eq(handle.status().status,"ORIGINAL_P3_CLIENT_LEASE_READONLY_BOUND",
   "C9 no server settlement claims from P3 read facade")
  eq(handle.status().authorizesOffer,false,"C9 never authorizes offers")
  eq(handle.status().authorizesAccept,false,"C9 final Accept remains false")
  eq(#x.sends,0,"C9 binding never sends any original remote")
  x.add(x.theirs,1,"Emberbow",1)
  eq(handle.isBoundSession(),true,
   "C9 same original protected lease supports actual GUI revision observation")
  x.name.Text="SpoofedPartner"
  eq(handle.isBoundSession(),false,
   "C9 original coordinator rejects GUI partner mismatch")
  x.name.Text="TrustedAlt"
  eq(handle.isBoundSession(),false,
   "C9 permanently revoked after original partner identity mismatch")
  eq(handle.status().status,"BLOCKED",
   "C9 fake recovery after revocation cannot revive lease")
  eq(#x.sends,0,"C9 revoked lease never sends remote")
 end
 do
  local x=factory()
  x.ctx.job="MAIN_C9_NATIVE_JOB_0002"
  local manager=bind(x)
  accept(x)
  local game={PlaceId=142823291,JobId=x.ctx.job,
  GetService=function(_,key)
   if key=="Players" then return x.players end
  end}
  local bound={jobId=x.ctx.job,session="p3stage119:"..tostring(x.ctx.epoch),
   root=x.trade,localPlayer=x.lp,partnerPlayer=x.p}
  local running=true
  local host={supervisor={
    currentBoundReadOnly=manager.currentBoundReadOnly,
    isP3Paused=x.p3.isPaused,
   },readOriginalHostBoundScope=function()return bound end,
   getJobId=x.ctx.getJobId,getP3Session=x.ctx.getP3Session,
   isOriginalHostRunning=function()return running end,
   io=x.io,players=x.players,game=game}
  local handle=a.new(host)
  eq(type(handle),"table","C9 bound original untouched real P3 client-only fixture")
  eq(handle.isBoundSession(),true,"C9 session active before hidden replacement")
  -- ABA: same exact JobId/epoch/partner/root, but lexical boundScope table
  -- replaced as it would be after the original host attaches a new trade.
  local original=bound
  bound={jobId=original.jobId,session=original.session,
    root=original.root,localPlayer=original.localPlayer,
    partnerPlayer=original.partnerPlayer}
  eq(handle.isBoundSession(),false,
   "C9 different original boundScope table invalidates same-name same-job ABA")
  bound=original
  eq(handle.isBoundSession(),false,"C9 ABA invalidation irreversible")
  eq(#x.sends,0,"C9 ABA scenario sends no game remotes")
 end
 do
  local x=factory()
  x.ctx.job="MAIN_C9_NATIVE_JOB_0003"
  local manager=bind(x)
  accept(x)
  local game={PlaceId=142823291,JobId=x.ctx.job,
  GetService=function(_,key)
   if key=="Players" then return x.players end
  end}
  local bound={jobId=x.ctx.job,session="p3stage119:"..tostring(x.ctx.epoch),
   root=x.trade,localPlayer=x.lp,partnerPlayer=x.p}
  local host={supervisor={
   currentBoundReadOnly=manager.currentBoundReadOnly,
   isP3Paused=x.p3.isPaused,
  },readOriginalHostBoundScope=function()return bound end,
  getJobId=x.ctx.getJobId,getP3Session=x.ctx.getP3Session,
  isOriginalHostRunning=function()return true end,
  io=x.io,players=x.players,game=game}
  local handle=a.new(host)
  eq(type(handle),"table","C9 original P3 accepted client-only state bound")
  x.ctx.epoch+=1
  eq(handle.isBoundSession(),false,
   "C9 original P3 session epoch changes; no old authorization")
  x.ctx.epoch-=1
  eq(handle.isBoundSession(),false,"C9 restoring old P3 epoch cannot resurrect")
  eq(#x.sends,0,"C9 epoch invalidation sends no trade requests")
 end
 do
  local x=factory()
  x.ctx.job="MAIN_C9_NATIVE_JOB_0004"
  local manager=bind(x)
  accept(x)
  local game={PlaceId=142823291,JobId=x.ctx.job,
  GetService=function(_,key)
   if key=="Players" then return x.players end
  end}
  local bound={jobId=x.ctx.job,session="p3stage119:"..tostring(x.ctx.epoch),
   root=x.trade,localPlayer=x.lp,partnerPlayer=x.p}
  local host={supervisor={
   currentBoundReadOnly=manager.currentBoundReadOnly,
   isP3Paused=x.p3.isPaused,
  },readOriginalHostBoundScope=function()return bound end,
  getJobId=x.ctx.getJobId,getP3Session=x.ctx.getP3Session,
  isOriginalHostRunning=function()return true end,
  io=x.io,players=x.players,game=game}
  local handle=a.new(host)
  eq(handle.isBoundSession(),true,"C9 live before original P3 stop")
  manager.stop()
  eq(handle.isBoundSession(),false,"C9 original P3 coordinator stop revokes")
  eq(handle.isBoundSession(),false,"C9 stopped coordinator never recovers")
  eq(#x.sends,0,"C9 P3 stop never sends")
 end
 do
  local x=factory()
  x.ctx.job="MAIN_C9_NATIVE_JOB_0005"
  local manager=bind(x)
  accept(x)
  local game={PlaceId=142823291,JobId=x.ctx.job,
  GetService=function(_,key)
   if key=="Players" then return x.players end
  end}
  local bound={jobId=x.ctx.job,session="p3stage119:"..tostring(x.ctx.epoch),
   root=x.trade,localPlayer=x.lp,partnerPlayer=x.p}
  local supervisor={
   currentBoundReadOnly=manager.currentBoundReadOnly,
   isP3Paused=x.p3.isPaused,
  }
  local host={supervisor=supervisor,
    readOriginalHostBoundScope=function()return bound end,
    getJobId=x.ctx.getJobId,getP3Session=x.ctx.getP3Session,
    isOriginalHostRunning=function()return true end,
    io=x.io,players=x.players,game=game}
  local first=a.new(host)
  eq(type(first),"table","C9 original first accepted trade lease")
  x.screen.Enabled=false
  local ok,reason=manager.resumeAfterClose()
  eq(ok,true,"C9 original coordinator safely closes first trade")
  eq(reason,"P3_RESUMED_AFTER_CLIENT_TRADE_CLOSED","C9 uses original close")
  x.screen.Enabled=true
  x.players.other={Name="SecondAlt",DisplayName="Other",
   UserId=3,Parent=x.players}
  x.name.Text="SecondAlt"
  x.p3.state.processed[3]="trade-open"
  x.p3.paused=true
  local newer=manager.currentBoundReadOnly()
  eq(type(newer),"table","C9 original new independent protected trade created")
  eq(first.isBoundSession(),false,
   "C9 previous read facade rejects next trade with same P3 epoch")
  bound={jobId=x.ctx.job,session="p3stage119:"..tostring(x.ctx.epoch),
   root=x.trade,localPlayer=x.lp,partnerPlayer=x.players.other}
  local second=a.new(host)
  eq(type(second),"table","C9 new trusted original protected lease binds new trade")
  eq(first.scope.leaseId==second.scope.leaseId,false,
   "C9 locally independent leases never share P3/partner identity string")
  eq(second.scope.partnerUserId,3,"C9 new exact P3 processed partner")
  eq(second.isBoundSession(),true,"C9 new lease intact after first revoked")
  game.PlaceId=987654321
  eq(second.isBoundSession(),false,
   "C9 original MM2 PlaceId drift invalidates client lease even at same JobId")
  game.PlaceId=142823291
  eq(second.isBoundSession(),false,
   "C9 original PlaceId restoration cannot revive an invalidated lease")
  eq(#x.sends,0,"C9 no physical trade action across protected sessions")
 end
 do
  local x=fixture()
  x.ctx.job="MAIN_C9_REAL_SERVICE_REGRESSION"
  local manager=bind(x)
  acceptP3(x)
  local game={PlaceId=142823291,JobId=x.ctx.job,
   GetService=function(_,key)
    if key=="Players" then return x.players end
   end}
  local bound={jobId=x.ctx.job,session="p3stage119:"..tostring(x.ctx.epoch),
   root=x.trade,localPlayer=x.lp,partnerPlayer=x.p}
  local host={supervisor={
     currentBoundReadOnly=manager.currentBoundReadOnly,
     isP3Paused=x.p3.isPaused,
    },readOriginalHostBoundScope=function()return bound end,
    getJobId=x.ctx.getJobId,getP3Session=x.ctx.getP3Session,
    isOriginalHostRunning=function()return true end,
    io=x.io,players=x.players,game=game}
  local good,why=a.new(host)
  eq(type(good),"table","C9 original real Players service identity is accepted")
  eq(why,nil,"C9 genuine service has no constructor denial")
  local counterfeit={LocalPlayer=x.players.LocalPlayer,
   GetPlayerByUserId=x.players.GetPlayerByUserId}
  host.players=counterfeit
  local bad,reason=a.new(host)
  eq(bad,nil,"C9 counterfeit Players table cannot be used in protected host")
  eq(reason.reason,"ORIGINAL_P3_PLAYERS_SERVICE_NOT_GENUINE",
   "C9 must compare exact game GetService Players instance")
  host.players=x.players
  game.GetService=function()return nil end
  local nilService,missing=a.new(host)
  eq(nilService,nil,"C9 missing genuine Players service denies binding")
  eq(missing.reason,"ORIGINAL_P3_PLAYERS_SERVICE_NOT_GENUINE",
   "C9 no fake static Players wrapper")
  eq(#x.sends,0,"C9 Players identity adversarial regression makes zero trades")
 end
 print("SYSTEM2_C9_ORIGINAL_P3_PROTECTED_LEASE_ASSERTIONS_PASSED")
end
return M
