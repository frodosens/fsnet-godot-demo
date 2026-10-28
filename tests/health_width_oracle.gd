extends RefCounted
static var body_width_cache={}
static func body_width(texture):
    if body_width_cache.has(texture):return body_width_cache[texture]
    var image=texture.get_image();var width=image.get_width();var height=image.get_height()
    var visited={};var largest=0;var result=0
    # Largest connected alpha>=0.5 component ignores transparent margins and isolated specks.
    for y in range(height):
        for x in range(width):
            var start=y*width+x
            if visited.has(start) or image.get_pixel(x,y).a<0.5:continue
            var queue=[start];visited[start]=true;var cursor=0;var left=x;var right=x
            while cursor<queue.size():
                var point=queue[cursor];cursor+=1;var px=point%width;var py=point/width
                left=mini(left,px);right=maxi(right,px)
                for dy in range(-1,2):
                    for dx in range(-1,2):
                        var nx=px+dx;var ny=py+dy;var next=ny*width+nx
                        if nx<0 or ny<0 or nx>=width or ny>=height or visited.has(next):continue
                        if image.get_pixel(nx,ny).a>=0.5:visited[next]=true;queue.append(next)
            if queue.size()>largest:largest=queue.size();result=right-left+1
    body_width_cache[texture]=result
    return result
