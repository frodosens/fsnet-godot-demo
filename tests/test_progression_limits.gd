extends SceneTree
const C=preload('res://logic/content.gd')
const R=preload('res://logic/runtime.gd')
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL: ',label)
func _initialize():
 var data=C.default_content();data.id="z".repeat(40);data.width=16;data.height=16;data.terrain=[]
 for i in range(16):data.terrain.append('GGGGGGGGGGGGGGGG')
 var sample=data.units[0].duplicate(true);data.units=[]
 for i in range(16):
  var u=sample.duplicate(true);u.id='u'+str(i).pad_zeros(2)+'x'.repeat(37);u.x=i;u.y=1;u.ally=i<8;u.controller='player' if i<8 else 'ai';data.units.append(u)
 while data.abilities.size()<16:
  var a=data.abilities[0].duplicate(true);a.id='ability_'+str(data.abilities.size());data.abilities.append(a)
 while data.equipment.starting.size()<32:data.equipment.starting.append({'base':'sword','quality':2,'affixes':['keen','vital']})
 check(C.validate(data).is_empty(),'maximum valid definitions')
 var campaign={'roster':[],'completed':[]}
 for i in range(32):
  campaign.roster.append({'id':data.units[i].id if i<8 else 'a'+str(i).pad_zeros(2)+'z'.repeat(37),'xp':1620})
  campaign.completed.append('c'+str(i).pad_zeros(2)+'y'.repeat(37))
 campaign.completed[0]=data.id # Full ledger is playable only for an already recorded chapter.
 check(R.validate_campaign(campaign),'bounded max campaign valid')
 var a=R.new(data,campaign);var b=R.new(data);var snapshot=a.snapshot()
 check(snapshot.length()<16384 and b.restore(snapshot) and b.snapshot()==snapshot,'max legitimate snapshot fits unchanged transport and restores')
 var auth=preload('res://logic/authority.gd').new(data,campaign)
 var reply=auth.handle({'rules':auth.logic.rules_hash,'content':auth.logic.content_hash,'client':'limit-test-client'})
 check(JSON.stringify(reply).to_utf8_buffer().size()<30000,'max authority reply within native limit')
 var before=a.snapshot()
 check(not a.apply_command({'kind':'experience','actor_id':data.units[0].id,'step':1}) and a.snapshot()==before,'no client XP command')
 check(not a.restore(snapshot+',0') and a.snapshot()==before,'append garbage atomic reject')
 var wrong=reply.duplicate(true);wrong.rules=R.LEGACY_V5_HASH
 var session=preload('res://logic/session.gd').new();session.logic=R.new(data)
 check(not session.synchronize(wrong),'old rules rejected for network even though save migratable')
 print('PROGRESSION_LIMITS checks=',checks,' failures=',failures,' snapshot_bytes=',snapshot.length(),' reply_bytes=',JSON.stringify(reply).to_utf8_buffer().size())
 quit(1 if failures else 0)
