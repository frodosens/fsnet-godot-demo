extends RefCounted
static var scenes={}
static func scene(id):
 if scenes.is_empty():scenes=Content.normalize(JSON.parse_string(FileAccess.get_file_as_string('res://story/scenes.json')))
 return scenes.get(id,{})
static func content(number):
 if number<1 or number>3:return {}
 return Content.from_file('res://content/homeward/ch0%d.json'%number).get('data',{})
