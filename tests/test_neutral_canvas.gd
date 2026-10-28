extends SceneTree
var count=0
var failures=0
func check(ok,label):
 count+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('run')
func run():
 var L=load('res://view/map_sequence.gd');var lib=L.new('res://missing.json')
 # Decoder-only fixture: a movement image stands in for an equally sized
 # neutral texture. This fixture does NOT register a production actor profile.
 var path='assets/characters/chapter3/vera/map_motion/front_left/front_left_walk_00.png'
 var data={'version':1,'profiles':{'fixture':{'motion_only':true}}}
 for dir in L.DIRECTIONS:
  data.profiles.fixture[dir]={'neutral_guard':path,'neutral_canvas_width':128,'neutral_root':[64,120],'motion':{'frames':[path],'ticks':[1],'cycle_ticks':1,'root':[64,120],'flip_h':dir.ends_with('right')}}
 lib.configure(JSON.parse_string(JSON.stringify(data)));check(lib.errors.is_empty() and lib.profiles.has('fixture'),'declared128 loads')
 for dir in L.DIRECTIONS:
  var entry=lib.profiles.fixture[dir]
  check(entry.guard.get_size()==Vector2(128,128),'128 not cropped')
  check(entry.motion.flip_h==dir.ends_with('right'),'mirror survives')
  check(lib.motion('fixture',dir,1,entry.guard)==entry.motion.textures[0],'onegrid reset')
 for width in [null,true,'128',[],{},0,96.5,127,129,INF,NAN]:
  var bad=data.duplicate(true);bad.profiles.fixture.front_left.neutral_canvas_width=width;lib.configure(bad)
  check(not lib.profiles.has('fixture') and not lib.errors.is_empty(),'invalid width atomic fallback')
 for root in [null,[],[64],[64,120,0],[48,120],[64,119],[true,120],[64,NAN],[64,INF],{},'64,120']:
  var bad=data.duplicate(true);bad.profiles.fixture.front_left.neutral_root=root;lib.configure(bad)
  check(not lib.profiles.has('fixture'),'invalidroot fallback')
 var missing=data.duplicate(true);missing.profiles.fixture.front_left.erase('neutral_root');lib.configure(missing);check(not lib.profiles.has('fixture'),'128 requires explicitroot')
 var mismatch=data.duplicate(true);mismatch.profiles.fixture.front_left.neutral_canvas_width=96;mismatch.profiles.fixture.front_left.neutral_root=[48,120];lib.configure(mismatch);check(not lib.profiles.has('fixture'),'declared actualsize mismatch rejected')
 var old=JSON.parse_string(FileAccess.get_file_as_string(L.PATH));lib.configure(old);check(lib.errors.is_empty() and lib.profiles.size()==8,'legacy96 unchanged')
 print('NEUTRAL_CANVAS checks=',count,' failures=',failures)
 quit(1 if failures else 0)
