extends Control
const UI=preload('res://ui/style.gd')
const P=preload('res://story/player.gd')
var player=P.new()
var words
var speaker
var pause_button
var status
var box
var background
var actors=[]
var actor_ids=[]
var actor_textures={}
var emotes=[]
var emote_textures={}
var exit_prompt
var cursor_path='user://homeward_posthouse_cursor.json'
var inn=false
var scene_id='ch04_night_at_posthouse'
func _ready():
 theme=UI.make_theme()
 inn=App.session!=null and App.session.logic.content.id=='homeward_02'
 if inn:scene_id='ch02_after_watchhouse';cursor_path='user://homeward_inn_cursor.json'
 background=TextureRect.new();background.texture=load('res://assets/backgrounds/story_locations_v1/'+('inn_backroom_twilight' if inn else 'posthouse_night')+'.png');background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.texture_filter=TEXTURE_FILTER_NEAREST;background.mouse_filter=MOUSE_FILTER_IGNORE;add_child(background)
 for emotion in P.EMOTES:emote_textures[emotion]=load('res://assets/ui/story_emotes_v1/emote_'+emotion+'.png')
 for id in (['neri','mara','oren'] if inn else ['neri','mara','finn','oren']):
  actor_textures[id]={}
  for direction in ['front_left','front_right','back_left','back_right']:actor_textures[id][direction]=load('res://assets/sprites/iso4/idle_candidate/'+id+'/'+direction+'_idle_00.png')
  var actor=TextureRect.new();actor.texture=actor_textures[id]['front_right'];actor.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;actor.texture_filter=TEXTURE_FILTER_NEAREST;actor.mouse_filter=MOUSE_FILTER_IGNORE;add_child(actor);actors.append(actor);actor_ids.append(id)
  var bubble=TextureRect.new();bubble.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bubble.mouse_filter=MOUSE_FILTER_IGNORE;bubble.texture_filter=TEXTURE_FILTER_NEAREST;bubble.size=Vector2(36,36);add_child(bubble);emotes.append(bubble)
 box=PanelContainer.new();add_child(box)
 var col=UI.column(box,4);col.add_child(UI.label('旅店后屋' if inn else '第四章 · 废弃驿站',20))
 speaker=UI.label('',22);col.add_child(speaker);words=UI.paragraph('',650);words.custom_minimum_size.y=42;col.add_child(words)
 var row=HBoxContainer.new();col.add_child(row);row.add_child(UI.button('继续',advance));row.add_child(UI.button('跳过这段',skip))
 pause_button=UI.button('暂停',pause);row.add_child(pause_button)
 row.add_child(UI.button('保存',save_cursor));row.add_child(UI.button('离开这里' if inn else '完成本章',finish));row.add_child(UI.button('返回菜单',leave))
 status=UI.paragraph('',650);status.add_theme_font_size_override('font_size',14);col.add_child(status)
 player.start(preload('res://story/library.gd').scene(scene_id))
 if FileAccess.file_exists(cursor_path):
  var saved=preload('res://logic/content.gd').normalize(JSON.parse_string(FileAccess.get_file_as_string(cursor_path)))
  if saved is Dictionary and saved.get('origin','')==origin():player.restore(preload('res://story/library.gd').scene(scene_id),saved.get('cursor',{}))
 exit_prompt=ConfirmationDialog.new();exit_prompt.dialog_text='保存当前演出位置并退出？';add_child(exit_prompt)
 exit_prompt.confirmed.connect(func():
  if save_cursor():get_tree().quit())
 exit_prompt.canceled.connect(func():player.paused=false;pause_button.text='暂停')
 refresh();layout_stage()
func origin():return App.session.logic.state_hash() if App.session else ''
func layout_stage():
 var view=get_viewport_rect().size;var stage=Vector2(view.x,maxf(200,view.y-260));var scale_factor=maxf(stage.x/1280.0,stage.y/720.0);var offset=(stage-Vector2(1280,720)*scale_factor)*0.5
 background.position=offset;background.size=Vector2(1280,720)*scale_factor
 box.position=Vector2(20,view.y-260);box.size=Vector2(view.x-40,248);words.custom_minimum_size.x=view.x-90
 for i in range(actors.size()):
  var source=Vector2([0.27,0.43,0.59,0.75][i]*1280,0.70*720)
  var foot=offset+source*scale_factor
  foot=foot.clamp(Vector2(70,200),Vector2(view.x-70,box.position.y-12))
  var art_scale=1.35*scale_factor
  actors[i].texture=actor_textures[actor_ids[i]][player.looks.get(actor_ids[i],'front_right' if i<2 else 'front_left')]
  actors[i].size=Vector2(96,128)*art_scale;actors[i].position=foot-Vector2(48,120)*art_scale
  var emotion=player.bubbles.get(actor_ids[i],'');emotes[i].visible=not player.paused and not emotion.is_empty()
  if not emotion.is_empty():emotes[i].texture=emote_textures[emotion]
  emotes[i].position=foot-Vector2(18,120*art_scale+32)
func _process(delta):player.tick(int(delta*1000));refresh();layout_stage()
func refresh():
 var c=player.current();speaker.text={'mara':'玛拉','neri':'奈莉','finn':'芬恩','oren':'奥伦'}.get(c.get('speaker',''),'')
 words.text=c.get('text','')
 if c.is_empty():status.text='这一段结束了。可以继续。' if inn else '此段结束。第五章尚未开放；此过场不产生经验。'
func advance():player.revealed=true;player.advance();refresh()
func skip():player.skip();refresh()
func pause():player.paused=not player.paused;pause_button.text='恢复' if player.paused else '暂停'
func save_cursor():
 if not App.save_slot('auto').is_empty():status.text='战役保存失败，当前进度保留。';return false
 var f=FileAccess.open(cursor_path+'.tmp',FileAccess.WRITE)
 if not f:status.text='保存失败，原位置保留。';return false
 f.store_string(JSON.stringify({'origin':origin(),'cursor':player.save()}));f.flush();var e=f.get_error();f.close()
 if e!=OK or DirAccess.rename_absolute(cursor_path+'.tmp',cursor_path)!=OK:status.text='保存失败，原位置保留。';return false
 status.text='演出位置已保存；章节检查点保留。';return true
func leave():
 if save_cursor():App.return_to_menu()
func finish():
 if not player.current().is_empty():status.text='先完成或跳过当前段落。';return
 if inn:
  if scene_id not in App.presentation.seen:App.presentation.seen.append(scene_id)
  App.presentation.active='';App.presentation.line=0;App.presentation.erase('cue')
  if App.enter_next_chapter():get_tree().call_deferred('change_scene_to_file','res://main.tscn')
  else:status.text=App.last_error
  return
 if not App.finish_homeward_event('homeward_04_finish'):status.text='完成命令尚未确认。';return
 App.presentation.interlude_completed=4
 var issue=App.save_chapter_checkpoint()
 if not issue.is_empty():status.text=issue;return
 if not save_cursor():return
 status.text='第四章已完成，无战斗经验。第五章等待正式关卡与美术。'

func request_exit():
 player.paused=true;pause_button.text='恢复';exit_prompt.popup_centered()
func _unhandled_key_input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_ESCAPE:pause();get_viewport().set_input_as_handled()
  elif event.physical_keycode in [KEY_SPACE,KEY_ENTER]:advance();get_viewport().set_input_as_handled()
