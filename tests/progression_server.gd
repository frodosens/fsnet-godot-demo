extends 'res://server.gd'
func _initialize():
 super._initialize()
 authority=Authority.new(authority.logic.content,{'roster':[{'id':'mara','xp':59}],'completed':[]})
