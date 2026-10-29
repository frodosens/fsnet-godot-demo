extends 'res://server.gd'
func _initialize():
 super._initialize()
 authority=Authority.new(authority.logic.content,campaign_seed(authority.logic.content))

static func campaign_seed(data):
 var seed={'roster':[{'id':'mara','xp':59}],'completed':[]}
 var cap=OS.get_environment('AMBER_PROGRESSION_CAP')
 if cap in ['31','32']:
  for i in range(31):seed.completed.append('done_'+str(i).pad_zeros(2))
  if cap=='32':seed.completed.append(data.id)
 return seed
