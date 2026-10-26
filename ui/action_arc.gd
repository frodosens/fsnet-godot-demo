extends RefCounted
# Screen-space presentation only. Does not inspect or mutate battle rules.
const BUTTON_SIZE=Vector2(170,76)
const OFFSETS=[
    [Vector2(60,-140),Vector2(145,-50),Vector2(145,50),Vector2(60,140)],
    [Vector2(-220,-140),Vector2(-305,-50),Vector2(-305,50),Vector2(-220,140)],
    [Vector2(-330,-64),Vector2(-170,-156),Vector2(30,-156),Vector2(190,-64)],
    [Vector2(-330,64),Vector2(-170,156),Vector2(30,156),Vector2(190,64)]
]
static func visual_rect(position):
    # Includes selected LEFT travel, pointer, rim and maximum 1.00 selection scale.
    return Rect2(position-Vector2(44,12),Vector2(226,90))
static func area(rect):return maxf(0,rect.size.x)*maxf(0,rect.size.y)
static func solve(anchor,view,keepout,reserved=[]):
    var safe=Rect2(Vector2(20,80),Vector2(view.x-40,view.y-150))
    var best={};var best_score=INF
    for side in range(OFFSETS.size()):
        for adjustment in [Vector2.ZERO,Vector2(0,-64),Vector2(0,64),Vector2(-64,0),Vector2(64,0)]:
            var positions=[];var bounds=Rect2()
            for offset in OFFSETS[side]:
                var p=anchor+offset+adjustment-Vector2(32,32)
                positions.append(p)
                bounds=visual_rect(p) if positions.size()==1 else bounds.merge(visual_rect(p))
            var shift=Vector2(clampf(0,safe.position.x-bounds.position.x,safe.end.x-bounds.end.x),clampf(0,safe.position.y-bounds.position.y,safe.end.y-bounds.end.y))
            var score=side*120.0+adjustment.length()+shift.length()*2
            var shifted=[]
            for p in positions:
                p+=shift;shifted.append(p);var rect=visual_rect(p)
                score+=area(rect.intersection(keepout))*10000
                for obstacle in reserved:score+=area(rect.intersection(obstacle))*100
            if score<best_score:
                best_score=score;best={"positions":shifted,"bounds":Rect2(bounds.position+shift,bounds.size),"side":side,"keepout":keepout,"anchor":anchor,"score":score}
    return best
