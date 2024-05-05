import 'dart:math';
import 'package:notify/store/collector.dart';
import 'package:flutter/material.dart';

class StoreConnect{
  StoreConnect({
    required this.key,
    required this.store
  });
  String key;
  Collector store;
}

class Reactive<T> with ChangeNotifier{
  Reactive(T? value, {StoreConnect? storeConnection, bool nullable = false, bool log = false}){
    _nullable = nullable||value==null;
    if(storeConnection==null){
      var gkey = _generateKey();
      _store = Collector({gkey:value}, strongTyped: !_nullable);
      _key = gkey;
    }else{
      _store = storeConnection.store;
      _store.strongTyped = !nullable;
      _key = storeConnection.key;
      _store.set(_key, _store.get(_key)??value, false);
    }
    _store.logMessages = log;
  }

  String _key = '';
  bool _nullable = false;
  late Collector _store;
  final List<int> _watchIndex = [];

  Reactive<T> get setNullable{
    _store.strongTyped = false;
    _nullable = true;
    return this;
  }

  T get value => _store.get(_key);
  set value(T value){
    if(_nullable||value!=null){
      _store.set(_key, value);
      notifyListeners();
    }else{
      throw Exception("Value is null!");
    }
  }
  void unSee(){
    _store.unSee(_key);
  }
  void Function() watch(CallbackInputType<T> onUpdate){
    final index = _store.watch(_key, onUpdate);
    _watchIndex.add(index);
    return () => _store.unSeeAt(_key, index);
  }
  void removeWatcher(CallbackInputType<dynamic> watcher){
    _store.removeWatcher(_key, watcher);
  }
  @override
  void dispose(){
    super.dispose();
    if(_watchIndex.isNotEmpty) _store.destroy(_key);
  }
  String _generateKey(){
    var key = [
      for (var i = 0; i<10; i++)
        Random().nextInt(9)
    ].join('');
    return key;
  }
  ReactiveBuilder<T> toBuilder(Widget Function(BuildContext context, Reactive<T> reactive) builder) =>
      ReactiveBuilder<T>(reactive: this, builder: builder);

  factory Reactive.withStore(StoreConnect store, [T? optionalValue]) => Reactive(optionalValue, storeConnection: store);
  factory Reactive.Null() => Reactive(null);
}

class ReactiveBuilder<T> extends StatelessWidget{
  const ReactiveBuilder({
    super.key,
    required this.reactive,
    required this.builder,
  });
  final Reactive<T> reactive;
  final Widget Function(BuildContext context, Reactive<T> reactive) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: reactive,
      builder: (context, _) => builder(context, reactive)
    );
  }
}
