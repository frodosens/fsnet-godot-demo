extends RefCounted
static var enabled=false
static var samples={}
static func record(key,us):
    if not enabled:return
    if not samples.has(key):samples[key]=[]
    samples[key].append(us/1000.0)
static func summary():
    var out={}
    for key in samples:
        var values=samples[key];values.sort()
        out[key]={"calls":values.size(),"median_ms":values[values.size()/2],"p95_ms":values[mini(values.size()-1,int(values.size()*.95))]}
    return out
