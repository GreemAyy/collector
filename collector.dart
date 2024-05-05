import 'dart:developer' as dev;

class _EventEmitter {
    Map<String,List<Function?>> events = {};

    int getEventsCount(String key){
      return events[key]?.length??0;
    }
    void on(String eventName, void Function() callback){
      var event = events[eventName];
      if(event==null){
         events[eventName]=[];
      }
      events[eventName]!.add(callback);
    }
    void emit(String eventName, [dynamic value]){
      var callbacks = events[eventName];
      if(callbacks != null){
        for (var call in callbacks) {
          if(call!=null){
            call();
          }
        }
      }
    }
    void remove(String eventName){
      try{
        events.remove(eventName);
      }catch(e){
        rethrow;
      }
    }

    void removeOn(String key, CallbackInputType<dynamic> on){
      if(events[key]==null) return;
      int count = 0;
      events[key] = events[key]!.map((e) => e.toString()==on.toString()&&count==0?null:e).toList();
    }

    void removeAt(String eventName, int index){
      try{
        if(events[eventName]?.length==1){
          events[eventName]!.clear();
        }else{
          events[eventName]?[index] = null;
        }
        var isEveryNull = events[eventName]?.where((element) => element!=null).isEmpty??true;
        if(isEveryNull){
          events[eventName]?.clear();
        }
      }catch(e){rethrow;}
    }
}

typedef CallbackInputType<CallbackType> = void Function(CallbackType data);
typedef Deleter = void Function();

class Updater{
  Updater({
    this.debug = false,
    this.logMessages = false
  });
  bool debug;
  bool logMessages;
  final _logs = <String>[];
  final _emitter = _EventEmitter();
  final Map<String, dynamic> _localHolder = {};
  ({String key, dynamic data}) _lastUpdate = (key: '', data: null);
  static const _anyWatchKey = '@_/#_ANY_/#_WATCH_/#_@';

  void _log(String _){
    if(debug) _logs.add(_);
    if(logMessages) dev.log(_, name: 'Updater debug mode');
  }

  void update(String key){
    final _ = 'update: $key events -> ${_emitter.events[key]}';
    _log(_);
    _emitter.emit(key);
  }
  void updateWithData(String key, dynamic data){
    final _ = 'update: $key value: $data events -> ${_emitter.events[key]}';
    _log(_);
    _localHolder[key] = data;
    _emitter.emit(key);
  }
  int watch<CallbackType>(String key, CallbackInputType<CallbackType> callback){
    final _ = 'watch_created: $key watchers_count: ${_emitter.getEventsCount(key)+1}';
    _log(_);
    _emitter.on(key, (){
      final _ = 'watch_created: $key watchers_count: ${_emitter.getEventsCount(key)+1}';
      _log(_);
      callback(_localHolder[key]);
      _lastUpdate = (key: key, data:_localHolder[key]);
      _emitter.emit(_anyWatchKey);
    });
    if(_localHolder[key]!=null){
      _localHolder.remove(key);
    }
    return _emitter.getEventsCount(key)-1;
  }
  Deleter watchWithDeleteCallback<CallbackType>(String key, CallbackInputType<CallbackType> callback){
    final watchIndex = watch(key, callback);
    return () => unSeeAt(key, watchIndex);
  }
  void anyWatch(void Function(String key, dynamic data) callback){
    _emitter.on(_anyWatchKey, () {
      callback(_lastUpdate.key, _lastUpdate.data);
    });
  }
  void unSee(String key){
    final _ = 'remove: $key';
    _log(_);
    _emitter.remove(key);
  }
  void multiUnSee(List<String> keys){
    for (var key in keys) {
      unSee(key);
    }
  }
  void unSeeAt(String key, int index){
    final _ = 'remove: $key at: $index';
    _log(_);
    _emitter.removeAt(key, index);
  }
  void removeWatcher(String key, CallbackInputType<dynamic> watcher){
    _emitter.removeOn(key, watcher);
  }
}

class Collector extends Updater {
  Collector(Map<String, dynamic> states, {
    this.strongTyped = true,
    super.debug,
    super.logMessages
  }) : _states = states;
  late final Map<String, dynamic> _states;
  bool strongTyped;

  Map<String, dynamic> get $ => _states;

  bool isNull(String key) => _states[key]==null;
  bool isNotNull(String key) => !isNull(key);

  Collector get unType{
    strongTyped = false;
    return this;
  }

  Collector get onType{
    strongTyped = true;
    return this;
  }

  void set(String key, dynamic value, [bool shouldUpdate = true]){
    var valueAt = _states[key];
    if(valueAt == value) return;
    if(valueAt!=null&&!identical(value.runtimeType, valueAt.runtimeType)&&strongTyped){
      throw Exception('New value type at key :$key is not matches to setted value');
    }
    final _ = 'set: $key value: $value';
    _log(_);

    _states[key] = value;
    if(shouldUpdate){
      _localHolder[key] = value;
      _emitter.emit(key);
    }
  }

  void waitSet(String key, dynamic value, [bool shouldUpdate = true]){
    Future.microtask(() => set(key, value, shouldUpdate));
  }

  void mapMultiSet(Map<String, dynamic> value){
    value.forEach((key, value) {
      var valueAt = _states[key];
      if(valueAt!=null&&!identical(value.runtimeType, valueAt.runtimeType)&&strongTyped){
        throw Exception('New value type at key :$key is not matches to setted value');
      }
      _log('set: $key value: $value');
      if(value is Map<String, dynamic> && value["--update"] != null){
        _states[key] = value["--update"];
      }else{
        _states[key] = value;
        _localHolder[key] = value;
        _emitter.emit(key);
      }
    });
  }

  void multiSet(List<String> keys, List<dynamic> values, [List<bool> shouldUpdate = const []]){
    for(int i = 0; i < keys.length; i++){
      var key = keys[i];
      var value = values[i];
      var valueAt = _states[key];
      if(valueAt!=null&&!identical(value.runtimeType, valueAt.runtimeType)&&strongTyped){
        throw Exception('New value type at key :$key is not matches to setted value');
      }

      final _ = 'set: $key value: $value';
      _log(_);

      _states[key] = value;
      _localHolder[key] = value;
      if(keys.length == shouldUpdate.length && shouldUpdate[i]){
        _emitter.emit(key);
      }else if(shouldUpdate.length == 1 && shouldUpdate[0]){
        _emitter.emit(key);
      }else if(shouldUpdate.length<keys.length && shouldUpdate.isNotEmpty){
        if(i > shouldUpdate.length -1 && shouldUpdate.last){
          _emitter.emit(key);
        }else if(shouldUpdate[i]){
          _emitter.emit(key);
        }
      }else{
        _emitter.emit(key);
      }
    }
  }

  T? get<T>(String key) => _states[key];
  T getNotNull<T>(String key) => get(key)!;

  void destroy(String key){
    try{
      final _ = 'remove: $key';
      _log(_);
      _states.remove(key);
      _emitter.remove(key);
    }catch(e){
      rethrow;
    }
  }
}