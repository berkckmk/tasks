/// Caps how many documents a list stream pulls down.
///
/// Every list query used to be unbounded, so an account with years of
/// history streamed its entire collection into memory on first read and
/// re-streamed on every change — Firestore bills per document read, and the
/// screens render these into non-builder ListViews. These screens show a
/// reverse-chronological feed, so the newest [kListPageLimit] is what's
/// actually reachable by scrolling anyway.
const int kListPageLimit = 200;
