import 'emitted_tree.dart';
import 'mutation_records.dart';
import 'serialized_node.dart';

/// Diffs two consecutive [EmittedTree]s (post-flatten, keyed on stable id)
/// into an rrweb mutation payload. The contract is the apply-invariant:
/// applying the result to a mirror built from [prev] reproduces [next].
///
/// Design (per the design panel): diff the EMITTED structure per-parent, not
/// raw IR. Structural ops (add/remove/move/reorder) act on element nodes; a
/// node that is re-added re-adds its whole subtree (downward closure), so the
/// result is correct regardless of whether the player keeps children on a
/// re-add. Text nodes are slaved to their div: inlined when the div is added,
/// added/removed independently when only the text appears/disappears, and
/// updated via a TextRecord when only the content changes.
class IncrementalDiffGenerator {
  MutationData? generateMutations(EmittedTree prev, EmittedTree next) {
    final prevIds = prev.byId.keys.toSet();
    final nextIds = next.byId.keys.toSet();
    final removedIds = prevIds.difference(nextIds);
    final addedIds = nextIds.difference(prevIds);
    final common = prevIds.intersection(nextIds);

    // Reclassified: same id, but tagName or class-set changed (e.g. box ->
    // paragraph, or div -> img). Must be removed and re-added, not patched.
    final forceReplace = <int>{};
    for (final id in common) {
      final p = prev.byId[id]!;
      final n = next.byId[id]!;
      if (p.type != n.type) {
        forceReplace.add(id);
      } else if (p.isElement &&
          (p.tagName != n.tagName || _classOf(p) != _classOf(n))) {
        forceReplace.add(id);
      }
    }

    // Element nodes needing (re-)add: newly added, moved to a new parent,
    // reordered within a parent, or force-replaced.
    final needsAdd = <int>{};
    for (final id in addedIds) {
      if (next.byId[id]!.isElement) needsAdd.add(id);
    }
    for (final id in common) {
      if (!next.byId[id]!.isElement) continue;
      if (prev.parentOf[id] != next.parentOf[id]) needsAdd.add(id);
    }
    for (final id in forceReplace) {
      if (next.byId[id]!.isElement) needsAdd.add(id);
    }
    needsAdd.addAll(_reorderReseats(prev, next, common));

    // Re-adding a node re-adds its whole emitted subtree.
    _closeDownward(next, needsAdd);

    // Text nodes are emitted as their OWN standalone add records — never
    // nested in a div's node.childNodes — because rrweb's applyMutation builds
    // added nodes with skipChild:true and drops nested children. A text node
    // needs (re-)adding when it is newly appeared OR its owning div is being
    // re-added (move/reorder/reclassify), since the div's add no longer
    // carries it.
    final needsAddText = <int>{};
    for (final id in next.byId.keys) {
      final n = next.byId[id]!;
      if (!n.isText) continue;
      if (addedIds.contains(id) || needsAdd.contains(next.parentOf[id])) {
        needsAddText.add(id);
      }
    }

    // Precompute each node's nextId once (O(n) total) instead of an indexOf +
    // forward scan per re-added node (which is O(n^2) on a wide parent).
    final nextIdOf = _precomputeNextIds(prev, next, needsAdd, needsAddText, common);

    final data = MutationData();

    // PHASE 1 — removes. Top-of-subtree only (the player prunes descendants);
    // a removed node whose parent is also removed is skipped. Plus the old
    // copies of force-replaced nodes.
    for (final id in removedIds) {
      final parent = prev.parentOf[id]!;
      if (!removedIds.contains(parent)) {
        data.removes.add(RemoveRecord(parentId: parent, id: id));
      }
    }
    for (final id in forceReplace) {
      data.removes.add(RemoveRecord(parentId: prev.parentOf[id]!, id: id));
    }

    // PHASE 2 — adds, in document order (DFS over next so a parent is added
    // before its children). Every node is a flat, childless add (rrweb builds
    // adds with skipChild:true), so a div's text child arrives as its own add.
    void dfs(int id) {
      final n = next.byId[id]!;
      if (n.isElement) {
        if (needsAdd.contains(id)) {
          data.adds.add(AddRecord(
            parentId: next.parentOf[id]!,
            nextId: nextIdOf[id],
            node: _shallowSerialize(next, id),
          ));
        }
        for (final c in n.childIds) {
          dfs(c);
        }
      } else if (needsAddText.contains(id)) {
        data.adds.add(AddRecord(
          parentId: next.parentOf[id]!,
          nextId: nextIdOf[id],
          node: SerializedNode.textNode(id: id, textContent: n.textContent!),
        ));
      }
    }

    for (final id in next.rootChildIds) {
      dfs(id);
    }

    // PHASE 3 — text content changes for surviving text nodes. Skipped when
    // the text is being (re-)added this frame (its add carries the content).
    for (final id in common) {
      final p = prev.byId[id]!;
      final n = next.byId[id]!;
      if (p.isText &&
          n.isText &&
          !needsAddText.contains(id) &&
          p.textContent != n.textContent) {
        data.texts.add(TextRecord(id: id, value: n.textContent!));
      }
    }

    // PHASE 4 — attribute changes. Emitted for surviving elements including
    // moved/reordered ones (same reason as PHASE 3: a move-add may not carry
    // attrs to the player). Skipped only for force-replaced nodes, whose fresh
    // add already carries the new attributes.
    for (final id in common) {
      if (forceReplace.contains(id)) continue;
      final p = prev.byId[id]!;
      final n = next.byId[id]!;
      if (p.isElement && n.isElement && !_mapEq(p.attributes!, n.attributes!)) {
        data.attributes.add(AttributeRecord(id: id, attributes: n.attributes!));
      }
    }

    return data.isEmpty ? null : data;
  }

  // --- helpers ---

  String? _classOf(EmittedNode n) => n.attributes?['class'];

  List<int> _childrenOf(EmittedTree t, int parent) =>
      t.byId.containsKey(parent) ? t.byId[parent]!.childIds : t.rootChildIds;

  /// Per-parent LIS: among element children present under the same parent in
  /// both frames, the longest order-preserving subsequence keeps its seats;
  /// the rest must be re-seated (minimal reorder).
  Set<int> _reorderReseats(EmittedTree prev, EmittedTree next, Set<int> common) {
    final reseats = <int>{};
    final parents = next.parentOf.values.toSet();
    for (final p in parents) {
      bool stable(int c, EmittedTree t) =>
          (t.byId[c]?.isElement ?? false) &&
          common.contains(c) &&
          prev.parentOf[c] == p &&
          next.parentOf[c] == p;

      final prevOrder =
          _childrenOf(prev, p).where((c) => stable(c, prev)).toList();
      final nextOrder =
          _childrenOf(next, p).where((c) => stable(c, next)).toList();
      if (prevOrder.length < 2 || _listEq(prevOrder, nextOrder)) continue;

      final prevIndex = <int, int>{};
      for (var i = 0; i < prevOrder.length; i++) {
        prevIndex[prevOrder[i]] = i;
      }
      final seq = nextOrder.map((c) => prevIndex[c]!).toList();
      final keep = _longestIncreasingSubsequence(seq).toSet();
      for (var i = 0; i < nextOrder.length; i++) {
        if (!keep.contains(i)) reseats.add(nextOrder[i]);
      }
    }
    return reseats;
  }

  void _closeDownward(EmittedTree next, Set<int> needsAdd) {
    final stack = needsAdd.toList();
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      for (final c in _childrenOf(next, id)) {
        if ((next.byId[c]?.isElement ?? false) && needsAdd.add(c)) {
          stack.add(c);
        }
      }
    }
  }

  /// For every node, its nextId: the first following sibling (under its
  /// next-parent) that is already in the mirror at apply time — in both frames
  /// under this parent and not itself being re-added — or null to append.
  /// Never points at a pending add, so it can't dangle. Computed in one
  /// right-to-left pass per parent (O(n) total) rather than a scan per node.
  Map<int, int?> _precomputeNextIds(EmittedTree prev, EmittedTree next,
      Set<int> needsAdd, Set<int> needsAddText, Set<int> common) {
    final out = <int, int?>{};
    for (final parent in next.parentOf.values.toSet()) {
      final siblings = _childrenOf(next, parent);
      int? survivorAfter;
      for (var j = siblings.length - 1; j >= 0; j--) {
        final s = siblings[j];
        out[s] = survivorAfter;
        final isSurvivor = common.contains(s) &&
            prev.parentOf[s] == next.parentOf[s] &&
            !needsAdd.contains(s) &&
            !needsAddText.contains(s);
        if (isSurvivor) survivorAfter = s;
      }
    }
    return out;
  }

  /// A flat, childless element. rrweb's appendNode builds adds with
  /// skipChild:true, so children (including the text child) must arrive as
  /// their own add records, not nested here.
  SerializedNode _shallowSerialize(EmittedTree next, int id) {
    final n = next.byId[id]!;
    return SerializedNode.elementNode(
      id: n.id,
      tagName: n.tagName!,
      attributes: n.attributes!,
      childNodes: const [],
    );
  }

  bool _mapEq(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Returns the indices (into [seq]) forming a longest strictly-increasing
  /// subsequence.
  List<int> _longestIncreasingSubsequence(List<int> seq) {
    if (seq.isEmpty) return const [];
    final n = seq.length;
    final parent = List<int>.filled(n, -1);
    final tailIdx = <int>[]; // indices into seq of LIS tails by length
    for (var i = 0; i < n; i++) {
      // binary search for first tail >= seq[i]
      var lo = 0;
      var hi = tailIdx.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (seq[tailIdx[mid]] < seq[i]) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      if (lo > 0) parent[i] = tailIdx[lo - 1];
      if (lo == tailIdx.length) {
        tailIdx.add(i);
      } else {
        tailIdx[lo] = i;
      }
    }
    final result = <int>[];
    var k = tailIdx.last;
    while (k != -1) {
      result.add(k);
      k = parent[k];
    }
    return result.reversed.toList();
  }
}
