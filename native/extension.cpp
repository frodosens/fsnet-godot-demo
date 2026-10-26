#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <fsnet/node.hpp>
extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}
#include <cstdlib>
#include <memory>
#include <map>
#include <string>
using namespace godot;

class AmberLogic : public RefCounted {
 GDCLASS(AmberLogic, RefCounted)
 lua_State *vm=nullptr;
 size_t used=0;
 int module=LUA_NOREF;
 String error;
 static void *allocate(void *ud,void *p,size_t old,size_t n) {
  auto *self=static_cast<AmberLogic*>(ud); if(!p) old=0;
  if(n==0){self->used-=old;std::free(p);return nullptr;}
  if(n>8*1024*1024 || self->used-old>8*1024*1024-n) return nullptr;
  void *out=std::realloc(p,n); if(out) self->used=self->used-old+n;return out;
 }
 static void budget(lua_State *l,lua_Debug*) {luaL_error(l,"instruction budget exceeded");}
 static void validate(const Variant&v,size_t &bytes,int depth=0){
  if(depth>12)throw std::runtime_error("input nesting limit");
  bytes+=16;if(bytes>131072)throw std::runtime_error("input size limit");
  if(v.get_type()==Variant::STRING||v.get_type()==Variant::STRING_NAME){
   bytes+=String(v).utf8().length();if(bytes>131072)throw std::runtime_error("input size limit");
  }else if(v.get_type()==Variant::ARRAY){
   Array a=v;if(a.size()>256)throw std::runtime_error("input array limit");
   for(int i=0;i<a.size();++i)validate(a[i],bytes,depth+1);
  }else if(v.get_type()==Variant::DICTIONARY){
   Dictionary d=v;Array keys=d.keys();if(keys.size()>32)throw std::runtime_error("input key limit");
   for(int i=0;i<keys.size();++i){validate(keys[i],bytes,depth+1);validate(d[keys[i]],bytes,depth+1);}
  }else if(v.get_type()!=Variant::NIL&&v.get_type()!=Variant::INT&&v.get_type()!=Variant::BOOL)throw std::runtime_error("unsupported input type");
 }
 static void push(lua_State*l,const Variant&v,int depth=0){
  if(depth>12) throw std::runtime_error("input nesting limit");
  switch(v.get_type()){
   case Variant::NIL:lua_pushnil(l);break;
   case Variant::BOOL:lua_pushboolean(l,bool(v));break;
   case Variant::INT:lua_pushinteger(l,int64_t(v));break;
   case Variant::STRING_NAME:
   case Variant::STRING:{auto s=String(v).utf8();lua_pushlstring(l,s.get_data(),s.length());break;}
   case Variant::ARRAY:{Array a=v;lua_createtable(l,a.size(),0);for(int i=0;i<a.size();++i){push(l,a[i],depth+1);lua_rawseti(l,-2,i+1);}break;}
   case Variant::DICTIONARY:{Dictionary d=v;Array keys=d.keys();lua_createtable(l,0,keys.size());
    for(int i=0;i<keys.size();++i){if(keys[i].get_type()!=Variant::STRING && keys[i].get_type()!=Variant::STRING_NAME)throw std::runtime_error("string keys only");push(l,keys[i],depth+1);push(l,d[keys[i]],depth+1);lua_rawset(l,-3);}break;}
   default:throw std::runtime_error("only integer, bool, string, array and dictionary inputs");
  }
 }
 static Variant read(lua_State*l,int index,int depth=0){
  if(depth>12) throw std::runtime_error("output nesting limit");index=lua_absindex(l,index);
  switch(lua_type(l,index)){
   case LUA_TNIL:return Variant();
   case LUA_TBOOLEAN:return bool(lua_toboolean(l,index));
   case LUA_TNUMBER:if(!lua_isinteger(l,index))throw std::runtime_error("floating rule output forbidden");return int64_t(lua_tointeger(l,index));
   case LUA_TSTRING:{size_t n;const char*s=lua_tolstring(l,index,&n);return String::utf8(s,n);}
   case LUA_TTABLE:{size_t n=lua_rawlen(l,index);if(n){Array out;for(size_t i=1;i<=n;++i){lua_rawgeti(l,index,i);out.push_back(read(l,-1,depth+1));lua_pop(l,1);}return out;}
    Dictionary out;lua_pushnil(l);while(lua_next(l,index)){if(lua_type(l,-2)!=LUA_TSTRING)throw std::runtime_error("invalid rule key");out[read(l,-2,depth+1)]=read(l,-1,depth+1);lua_pop(l,1);}return out;}
   default:throw std::runtime_error("invalid rule output");
  }
 }
 void close(){if(vm)lua_close(vm);vm=nullptr;module=LUA_NOREF;used=0;}
protected:
 static void _bind_methods(){ClassDB::bind_method(D_METHOD("load_rules","source"),&AmberLogic::load_rules);ClassDB::bind_method(D_METHOD("invoke","method","args"),&AmberLogic::invoke);ClassDB::bind_method(D_METHOD("last_error"),&AmberLogic::last_error);}
public:
 ~AmberLogic(){close();}
 String last_error()const{return error;}
 bool load_rules(String source){
  close();error="";if(source.utf8().length()>65536){error="rules source size limit";return false;}vm=lua_newstate(allocate,this);if(!vm){error="Lua allocation failed";return false;}
  // Only a bundled, trusted rules module is loaded. No peer-provided source.
  luaL_requiref(vm,"_G",luaopen_base,1);lua_pop(vm,1);
  luaL_requiref(vm,LUA_TABLIBNAME,luaopen_table,1);lua_pop(vm,1);
  luaL_requiref(vm,LUA_STRLIBNAME,luaopen_string,1);lua_pop(vm,1);
  luaL_requiref(vm,LUA_MATHLIBNAME,luaopen_math,1);lua_pop(vm,1);
  for(const char *name:{"dofile","loadfile","load","collectgarbage","print","warn"}){lua_pushnil(vm);lua_setglobal(vm,name);}
  lua_getglobal(vm,"math");for(const char*name:{"random","randomseed"}){lua_pushnil(vm);lua_setfield(vm,-2,name);}lua_pop(vm,1);
  auto bytes=source.utf8();lua_sethook(vm,budget,LUA_MASKCOUNT,2000000);
  if(luaL_loadbufferx(vm,bytes.get_data(),bytes.length(),"battle.lua","t")||lua_pcall(vm,0,1,0)){
   error=String::utf8(lua_tostring(vm,-1));close();return false;
  }
  if(!lua_istable(vm,-1)){error="rules module must return table";close();return false;}
  module=luaL_ref(vm,LUA_REGISTRYINDEX);return true;
 }
 Variant invoke(String method,Dictionary args){
  error="";if(!vm){error="rules not loaded";return Variant();}
  int base=lua_gettop(vm);
  try{
   size_t bytes=0;validate(args,bytes);
   lua_rawgeti(vm,LUA_REGISTRYINDEX,module);auto name=method.utf8();lua_getfield(vm,-1,name.get_data());
   if(!lua_isfunction(vm,-1))throw std::runtime_error("unknown rules method");
   push(vm,args);lua_sethook(vm,budget,LUA_MASKCOUNT,2000000);
   if(lua_pcall(vm,1,1,0)){error=String::utf8(lua_tostring(vm,-1));lua_settop(vm,base);return Variant();}
   Variant out=read(vm,-1);lua_settop(vm,base);return out;
  }catch(const std::exception&e){error=String::utf8(e.what());lua_settop(vm,base);return Variant();}
 }
};

class AmberTransport : public RefCounted {
 GDCLASS(AmberTransport,RefCounted)
 // Godot main thread owns Node, callbacks, queues and destruction.
 std::unique_ptr<fsnet::Node> node;
 uint64_t peer=0,next=0;
 Array events;
 std::map<uint64_t,fsnet::Reply> requests;
 String error;
 bool closing=false;
 void fail(const std::exception&e){error=String::utf8(e.what());}
 void close_node(){closing=true;node.reset();requests.clear();events.clear();peer=0;closing=false;}
protected:
 static void _bind_methods(){
  ClassDB::bind_method(D_METHOD("start","server","port","token"),&AmberTransport::start);
  ClassDB::bind_method(D_METHOD("send","payload"),&AmberTransport::send);
  ClassDB::bind_method(D_METHOD("respond","id","payload"),&AmberTransport::respond);
  ClassDB::bind_method(D_METHOD("poll_events"),&AmberTransport::poll_events);
  ClassDB::bind_method(D_METHOD("shutdown"),&AmberTransport::shutdown);
  ClassDB::bind_method(D_METHOD("last_error"),&AmberTransport::last_error);
 }
public:
 ~AmberTransport(){close_node();}
 String last_error()const{return error;}
 void shutdown(){close_node();}
 bool start(bool server,int port,String token){
  close_node();error="";if(port<1||port>65535||token.length()<16){error="invalid port/token";return false;}
  try{
   fsnet::Limits limits;limits.connections=8;limits.pending_calls=16;limits.inflight_requests=16;limits.frame_bytes=32768;
   node=std::make_unique<fsnet::Node>(token.utf8().get_data(),limits);
   if(server){
    node->bind("amber",[this](std::string payload,fsnet::Reply reply){
     if(requests.size()>=32||events.size()>=64){reply({fsnet::Status::overloaded,{}});return;}
     uint64_t id=++next;requests.emplace(id,std::move(reply));Dictionary d;d["kind"]="request";d["id"]=int64_t(id);d["payload"]=String::utf8(payload.data(),payload.size());events.push_back(d);
    });
    node->listen("127.0.0.1",uint16_t(port));
   }else peer=node->connect("127.0.0.1",uint16_t(port));
   return true;
  }catch(const std::exception&e){fail(e);close_node();return false;}
 }
 bool send(String payload){
  if(!node||!peer||payload.utf8().length()>16384)return false;
  try{auto s=payload.utf8();node->call(peer,"amber",std::string_view(s.get_data(),s.length()),std::chrono::milliseconds(3000),[this](fsnet::Result result){
   if(closing||events.size()>=64)return;
   Dictionary d;d["kind"]="response";d["status"]=int(result.status);d["payload"]=String::utf8(result.data.data(),result.data.size());events.push_back(d);
  });return true;}catch(const std::exception&e){fail(e);return false;}
 }
 bool respond(int64_t id,String payload){
  auto it=requests.find(id);if(it==requests.end()||payload.utf8().length()>30000)return false;
  auto reply=std::move(it->second);requests.erase(it);
  try{auto s=payload.utf8();reply({fsnet::Status::ok,std::string(s.get_data(),s.length())});return true;}catch(const std::exception&e){fail(e);return false;}
 }
 Array poll_events(){
  if(node){try{node->poll();}catch(const std::exception&e){fail(e);}}
  Array out=events;events=Array();return out;
 }
};
void initialize(ModuleInitializationLevel level){if(level!=MODULE_INITIALIZATION_LEVEL_SCENE)return;ClassDB::register_class<AmberLogic>();ClassDB::register_class<AmberTransport>();}
void uninitialize(ModuleInitializationLevel){}
extern "C" GDExtensionBool GDE_EXPORT amber_library_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization){GDExtensionBinding::InitObject init(get_proc,library,initialization);init.register_initializer(initialize);init.register_terminator(uninitialize);init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return init.init();}
