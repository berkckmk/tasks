import 'dart:async';

/// Emits `(A, B)` every time either source stream emits, once both have
/// produced at least one value. Used to merge Firestore collection streams
/// (e.g. habits + their completion logs) without pulling in rxdart for a
/// single operator.
Stream<(A, B)> combineLatest2<A, B>(Stream<A> a, Stream<B> b) {
  late StreamController<(A, B)> controller;
  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  void emitIfReady() {
    if (hasA && hasB) controller.add((latestA as A, latestB as B));
  }

  controller = StreamController<(A, B)>(
    onListen: () {
      subA = a.listen(
        (event) {
          latestA = event;
          hasA = true;
          emitIfReady();
        },
        onError: controller.addError,
      );
      subB = b.listen(
        (event) {
          latestB = event;
          hasB = true;
          emitIfReady();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );

  return controller.stream;
}
