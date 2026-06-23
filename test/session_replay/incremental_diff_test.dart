/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

// The apply-invariant is the backbone: applying generateMutations(prev,next)
// to a mirror built from the prev FullSnapshot must reproduce the next
// FullSnapshot exactly (ids, tags, attrs, text, child order). A tiny mirror
// model below applies the rrweb mutation JSON in the fixed order
// removes -> adds -> texts -> attributes, then we compare canonical trees.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/src/session_replay/ir/ir_node.dart';
import 'package:newrelic_mobile/src/session_replay/ir/ir_style.dart';
import 'package:newrelic_mobile/src/session_replay/rrweb/emitted_tree.dart';
import 'package:newrelic_mobile/src/session_replay/rrweb/full_snapshot_builder.dart';
import 'package:newrelic_mobile/src/session_replay/rrweb/incremental_diff_generator.dart';

// ---------- mirror model ----------

class _MNode {
  int? parent;
  String? tag;
  Map<String, String> attrs;
  String? text;
  List<int> children;
  bool isText;
  _MNode({
    this.parent,
    this.tag,
    Map<String, String>? attrs,
    this.text,
    List<int>? children,
    this.isText = false,
  })  : attrs = attrs ?? {},
        children = children ?? [];
}

const int _bodyId = FullSnapshotBuilder.idBody;

Map<int, _MNode> _initMirror(EmittedTree t) {
  final m = <int, _MNode>{};
  m[_bodyId] = _MNode(tag: 'body', children: List.of(t.rootChildIds));
  for (final e in t.byId.entries) {
    final n = e.value;
    m[e.key] = _MNode(
      parent: t.parentOf[e.key],
      tag: n.tagName,
      attrs: n.attributes == null ? {} : Map.of(n.attributes!),
      text: n.textContent,
      children: List.of(n.childIds),
      isText: n.isText,
    );
  }
  return m;
}

void _apply(Map<String, dynamic> data, Map<int, _MNode> m) {
  void del(int id) {
    final n = m[id];
    if (n == null) return;
    for (final c in List.of(n.children)) {
      del(c);
    }
    m.remove(id);
  }

  for (final r in (data['removes'] as List)) {
    final pid = r['parentId'] as int;
    final id = r['id'] as int;
    m[pid]?.children.remove(id);
    del(id);
  }

  // Models rrweb's appendNode, which builds adds with skipChild:true — a
  // node's nested childNodes are NOT built; every child must arrive as its
  // own add. (If a producer nests children in an add, this faithfully drops
  // them, so the apply-invariant catches it.)
  void register(Map node, int? parent) {
    final id = node['id'] as int;
    final type = node['type'] as int;
    m[id] = _MNode(
      parent: parent,
      tag: node['tagName'] as String?,
      attrs: (node['attributes'] as Map?)?.cast<String, String>() ?? {},
      text: node['textContent'] as String?,
      children: [],
      isText: type == 3,
    );
  }

  for (final a in (data['adds'] as List)) {
    final pid = a['parentId'] as int;
    final nextId = a['nextId'] as int?;
    final node = a['node'] as Map;
    final id = node['id'] as int;
    final oldParent = m[id]?.parent;
    if (oldParent != null) m[oldParent]?.children.remove(id);
    register(node, pid);
    final pch = m[pid]!.children;
    pch.remove(id);
    if (nextId == null) {
      pch.add(id);
    } else {
      final idx = pch.indexOf(nextId);
      idx < 0 ? pch.add(id) : pch.insert(idx, id);
    }
  }

  for (final t in (data['texts'] as List)) {
    m[t['id'] as int]?.text = t['value'] as String;
  }
  for (final at in (data['attributes'] as List)) {
    m[at['id'] as int]?.attrs = (at['attributes'] as Map).cast<String, String>();
  }
}

dynamic _canonMirror(int id, Map<int, _MNode> m) {
  final n = m[id]!;
  if (n.isText) return {'id': id, 'text': n.text};
  return {
    'id': id,
    'tag': n.tag,
    'attrs': n.attrs,
    'children': n.children.map((c) => _canonMirror(c, m)).toList(),
  };
}

dynamic _canonTree(int id, EmittedTree t) {
  final n = t.byId[id]!;
  if (n.isText) return {'id': id, 'text': n.textContent};
  return {
    'id': id,
    'tag': n.tagName,
    'attrs': n.attributes,
    'children': n.childIds.map((c) => _canonTree(c, t)).toList(),
  };
}

List _mirrorRoots(Map<int, _MNode> m) =>
    m[_bodyId]!.children.map((c) => _canonMirror(c, m)).toList();
List _treeRoots(EmittedTree t) =>
    t.rootChildIds.map((c) => _canonTree(c, t)).toList();

final _builder = FullSnapshotBuilder();
final _gen = IncrementalDiffGenerator();

/// Asserts the apply-invariant for prev -> next and returns the mutation
/// (null if no-op).
dynamic _expectInvariant(IRNode prevIr, IRNode nextIr, {String? reason}) {
  final prev = _builder.buildEmitted(prevIr);
  final next = _builder.buildEmitted(nextIr);
  final mut = _gen.generateMutations(prev, next);
  final mirror = _initMirror(prev);
  if (mut != null) _apply(mut.toJson(), mirror);
  expect(_mirrorRoots(mirror), _treeRoots(next), reason: reason);
  return mut;
}

// ---------- IR builders (explicit ids => stable identity across frames) ----------

IRRect _r(int id, [int v = 0]) =>
    IRRect((id % 7) * 10.0 + v, (id ~/ 7) * 10.0, 20, 10);

IRNode _box(int id, {List<IRNode> children = const [], int v = 0}) => IRNode(
      type: 'box',
      renderType: 'RenderBox',
      bounds: _r(id, v),
      id: id,
      style: IRStyle(backgroundColor: 'rgb($v,0,0)'),
      children: children,
    );

IRNode _para(int id, int textId, String text, {int v = 0}) => IRNode(
      type: 'paragraph',
      renderType: 'RenderParagraph',
      bounds: _r(id, v),
      id: id,
      textId: textId,
      text: text,
    );

IRNode _img(int id, {int v = 0}) => IRNode(
      type: 'image',
      renderType: 'RenderImage',
      bounds: _r(id, v),
      id: id,
    );

IRNode _passthrough(List<IRNode> children) =>
    IRNode(type: 'passthrough', renderType: 'RenderView', children: children);

/// Applies each frame's diff to ONE mirror cumulatively (the real streaming
/// scenario), asserting the apply-invariant after every frame.
void _expectChain(List<IRNode> frames) {
  final trees = frames.map(_builder.buildEmitted).toList();
  final mirror = _initMirror(trees.first);
  for (var i = 1; i < trees.length; i++) {
    final mut = _gen.generateMutations(trees[i - 1], trees[i]);
    if (mut != null) _apply(mut.toJson(), mirror);
    expect(_mirrorRoots(mirror), _treeRoots(trees[i]), reason: 'frame $i');
  }
}

// Root screen container all scenarios hang under.
IRNode _screen(List<IRNode> children) => _box(100, children: children);

void main() {
  group('apply-invariant battery', () {
    test('no-op: identical trees produce no mutation', () {
      final mut = _expectInvariant(
        _screen([_para(101, 201, 'hi')]),
        _screen([_para(101, 201, 'hi')]),
      );
      expect(mut, isNull);
    });

    test('attribute-only: a box moves', () {
      final mut = _expectInvariant(
        _screen([_box(101)]),
        _screen([_box(101, v: 5)]),
      );
      expect(mut!.attributes.length, 1);
      expect(mut.attributes.first.id, 101);
      expect(mut.adds, isEmpty);
      expect(mut.removes, isEmpty);
      expect(mut.texts, isEmpty);
    });

    test('text-only: paragraph text changes -> TextRecord on textId', () {
      final mut = _expectInvariant(
        _screen([_para(101, 201, 'one')]),
        _screen([_para(101, 201, 'two')]),
      );
      expect(mut!.texts.length, 1);
      expect(mut.texts.first.id, 201);
      expect(mut.texts.first.value, 'two');
      expect(mut.attributes, isEmpty);
    });

    test('text + position change together', () {
      final mut = _expectInvariant(
        _screen([_para(101, 201, 'one')]),
        _screen([_para(101, 201, 'two', v: 3)]),
      );
      expect(mut!.texts.single.id, 201);
      expect(mut.attributes.single.id, 101);
    });

    test('add leaf at END', () {
      _expectInvariant(
        _screen([_box(101), _box(102)]),
        _screen([_box(101), _box(102), _box(103)]),
      );
    });

    test('add leaf in MIDDLE', () {
      _expectInvariant(
        _screen([_box(101), _box(103)]),
        _screen([_box(101), _box(102), _box(103)]),
      );
    });

    test('add leaf at FRONT', () {
      _expectInvariant(
        _screen([_box(102), _box(103)]),
        _screen([_box(101), _box(102), _box(103)]),
      );
    });

    test('add a subtree (bounded parent with bounded children)', () {
      _expectInvariant(
        _screen([_box(101)]),
        _screen([
          _box(101),
          _box(102, children: [_box(110), _box(111)]),
        ]),
      );
    });

    test('remove leaf', () {
      _expectInvariant(
        _screen([_box(101), _box(102)]),
        _screen([_box(101)]),
      );
    });

    test('remove a subtree (single remove of the root)', () {
      final mut = _expectInvariant(
        _screen([
          _box(101),
          _box(102, children: [_box(110), _box(111)]),
        ]),
        _screen([_box(101)]),
      );
      // Only the subtree root is named in removes.
      expect(mut!.removes.where((r) => r.id == 102).length, 1);
      expect(mut.removes.any((r) => r.id == 110 || r.id == 111), isFalse);
    });

    test('reorder 3 siblings A,B,C -> C,A,B (minimal re-seat)', () {
      _expectInvariant(
        _screen([_box(101), _box(102), _box(103)]),
        _screen([_box(103), _box(101), _box(102)]),
      );
    });

    test('swap two siblings A,B -> B,A', () {
      _expectInvariant(
        _screen([_box(101), _box(102)]),
        _screen([_box(102), _box(101)]),
      );
    });

    test('cross-parent move of a leaf', () {
      _expectInvariant(
        _screen([
          _box(101, children: [_box(110)]),
          _box(102),
        ]),
        _screen([
          _box(101),
          _box(102, children: [_box(110)]),
        ]),
      );
    });

    test('cross-parent move of a subtree-bearing node', () {
      _expectInvariant(
        _screen([
          _box(101, children: [
            _box(110, children: [_box(120)]),
          ]),
          _box(102),
        ]),
        _screen([
          _box(101),
          _box(102, children: [
            _box(110, children: [_box(120)]),
          ]),
        ]),
      );
    });

    test('passthrough insertion does not change the emitted tree (null diff)',
        () {
      final mut = _expectInvariant(
        _screen([_para(101, 201, 'hi')]),
        _screen([
          _passthrough([_para(101, 201, 'hi')]),
        ]),
      );
      expect(mut, isNull);
    });

    test('passthrough loses bounds: bounded -> passthrough removes the div',
        () {
      _expectInvariant(
        _screen([
          _box(101, children: [_box(110)]),
        ]),
        _screen([
          _passthrough([_box(110)]),
        ]),
      );
    });

    test('paragraph text cleared (non-empty -> empty) removes the text node',
        () {
      final mut = _expectInvariant(
        _screen([_para(101, 201, 'gone')]),
        _screen([_para(101, 201, '')]),
      );
      expect(mut!.removes.single.id, 201);
      expect(mut.texts, isEmpty);
    });

    test('paragraph gains text (empty -> non-empty) adds the text node', () {
      final mut = _expectInvariant(
        _screen([_para(101, 201, '')]),
        _screen([_para(101, 201, 'now')]),
      );
      expect(mut!.adds.any((a) => a.node.toJson()['id'] == 201), isTrue);
    });

    test('reclassification: box -> paragraph forces remove + add', () {
      final mut = _expectInvariant(
        _screen([_box(101)]),
        _screen([_para(101, 201, 'now a paragraph')]),
      );
      expect(mut!.removes.any((r) => r.id == 101), isTrue);
      expect(mut.adds.any((a) => a.node.toJson()['id'] == 101), isTrue);
    });

    test('move + attribute change emits an AttributeRecord (player-independent)',
        () {
      final mut = _expectInvariant(
        _screen([
          _box(101, children: [_box(110)]),
          _box(102),
        ]),
        _screen([
          _box(101),
          _box(102, children: [_box(110, v: 7)]),
        ]),
      );
      expect(mut!.attributes.any((a) => a.id == 110), isTrue,
          reason: 'a moved node whose attrs changed must still get an attr record');
    });

    test('move + text change re-adds the text node with the new content', () {
      final mut = _expectInvariant(
        _screen([
          _box(101, children: [_para(110, 210, 'old')]),
          _box(102),
        ]),
        _screen([
          _box(101),
          _box(102, children: [_para(110, 210, 'new')]),
        ]),
      );
      // The moved div is re-added, so its text child is re-added standalone
      // with the new content (not a TextRecord).
      final textAdd = mut!.adds.firstWhere((a) => a.node.toJson()['id'] == 210);
      expect(textAdd.node.toJson()['textContent'], 'new');
    });

    test('reclassification box -> image forces remove + add of an img', () {
      final mut = _expectInvariant(
        _screen([_box(101)]),
        _screen([_img(101)]),
      );
      expect(mut!.removes.any((r) => r.id == 101), isTrue);
      expect(
          mut.adds.any((a) =>
              a.node.toJson()['id'] == 101 &&
              a.node.toJson()['tagName'] == 'img'),
          isTrue);
    });

    test('multi-frame chain: cumulative apply across 5 frames', () {
      _expectChain([
        _screen([_box(101), _box(102)]),
        _screen([_box(101), _box(102), _box(103)]), // add
        _screen([_box(103), _box(101), _box(102)]), // reorder
        _screen([_box(103), _para(101, 201, 'hi'), _box(102)]), // reclassify 101
        _screen([_box(103), _para(101, 201, 'bye')]), // text change + remove 102
      ]);
    });

    test('combined: text + style + add + remove + reorder in one frame', () {
      _expectInvariant(
        _screen([
          _para(101, 201, 'a'),
          _box(102),
          _box(103),
        ]),
        _screen([
          _box(103),
          _para(101, 201, 'b', v: 4),
          _box(104),
        ]),
      );
    });
  });

  group('fuzzer', () {
    test('apply-invariant holds over many random stable-id-preserving edits',
        () {
      for (var seed = 0; seed < 1500; seed++) {
        final rnd = Random(seed);
        final f = _FuzzGen(rnd);
        final tree = f.genTree();
        final prevIr = f.toIr(tree);
        f.mutate(tree);
        final nextIr = f.toIr(tree);
        _expectInvariant(prevIr, nextIr, reason: 'seed $seed');
      }
    });
  });
}

// ---------- fuzzer ----------

class _FuzzNode {
  final int id;
  final int? textId;
  String type; // 'box' | 'para' | 'pass'
  String text;
  int v = 0;
  List<_FuzzNode> children;
  _FuzzNode(this.id, this.textId, this.type, this.text, this.children);
}

class _FuzzGen {
  final Random rnd;
  int _nextId = 100;
  int _nextText = 5000;
  int _textCounter = 0;
  _FuzzGen(this.rnd);

  _FuzzNode _leaf() {
    final id = _nextId++;
    if (rnd.nextBool()) {
      return _FuzzNode(id, _nextText++, 'para', 't${_textCounter++}', []);
    }
    return _FuzzNode(id, null, 'box', '', []);
  }

  _FuzzNode genTree() {
    final root = _FuzzNode(_nextId++, null, 'box', '', []);
    final n = rnd.nextInt(4);
    for (var i = 0; i < n; i++) {
      root.children.add(_genSub(2));
    }
    return root;
  }

  _FuzzNode _genSub(int depth) {
    if (depth <= 0 || rnd.nextInt(3) == 0) return _leaf();
    final node = _FuzzNode(_nextId++, null, 'box', '', []);
    final n = rnd.nextInt(3);
    for (var i = 0; i < n; i++) {
      node.children.add(_genSub(depth - 1));
    }
    return node;
  }

  // Collect (node, parent) excluding the root.
  void _collect(_FuzzNode node, _FuzzNode? parent,
      List<MapEntry<_FuzzNode, _FuzzNode>> out) {
    if (parent != null) out.add(MapEntry(node, parent));
    for (final c in node.children) {
      _collect(c, node, out);
    }
  }

  bool _isDescendant(_FuzzNode a, _FuzzNode maybe) {
    if (identical(a, maybe)) return true;
    for (final c in a.children) {
      if (_isDescendant(c, maybe)) return true;
    }
    return false;
  }

  void mutate(_FuzzNode root) {
    final ops = 1 + rnd.nextInt(3);
    for (var i = 0; i < ops; i++) {
      _oneEdit(root);
    }
  }

  void _oneEdit(_FuzzNode root) {
    final all = <MapEntry<_FuzzNode, _FuzzNode>>[];
    _collect(root, null, all);
    final pick = rnd.nextInt(8);
    switch (pick) {
      case 0: // attribute change
        (all.isEmpty ? root : all[rnd.nextInt(all.length)].key).v++;
        break;
      case 1: // text change / toggle
        final paras = all.map((e) => e.key).where((n) => n.type == 'para').toList();
        if (paras.isNotEmpty) {
          final p = paras[rnd.nextInt(paras.length)];
          p.text = rnd.nextInt(4) == 0 ? '' : 't${_textCounter++}';
        }
        break;
      case 2: // remove a node
        if (all.isNotEmpty) {
          final e = all[rnd.nextInt(all.length)];
          e.value.children.remove(e.key);
        }
        break;
      case 3: // add a new leaf under a random node
        final hosts = [root, ...all.map((e) => e.key)];
        final host = hosts[rnd.nextInt(hosts.length)];
        host.children.insert(rnd.nextInt(host.children.length + 1), _leaf());
        break;
      case 4: // move a node under a different parent
        if (all.isNotEmpty) {
          final e = all[rnd.nextInt(all.length)];
          final node = e.key;
          final hosts = [root, ...all.map((x) => x.key)]
              .where((h) => !_isDescendant(node, h))
              .toList();
          if (hosts.isNotEmpty) {
            final host = hosts[rnd.nextInt(hosts.length)];
            e.value.children.remove(node);
            host.children.insert(rnd.nextInt(host.children.length + 1), node);
          }
        }
        break;
      case 5: // reorder a parent's children
        final parents =
            [root, ...all.map((e) => e.key)].where((n) => n.children.length >= 2).toList();
        if (parents.isNotEmpty) {
          parents[rnd.nextInt(parents.length)].children.shuffle(rnd);
        }
        break;
      case 6: // wrap a node in a passthrough
        if (all.isNotEmpty) {
          final e = all[rnd.nextInt(all.length)];
          final idx = e.value.children.indexOf(e.key);
          final pass = _FuzzNode(0, null, 'pass', '', [e.key]);
          e.value.children[idx] = pass;
        }
        break;
      case 7: // reclassify box <-> para
        final cands = all.map((e) => e.key).where((n) => n.type != 'pass').toList();
        if (cands.isNotEmpty) {
          final n = cands[rnd.nextInt(cands.length)];
          n.type = n.type == 'box' ? 'para' : 'box';
        }
        break;
    }
  }

  IRNode toIr(_FuzzNode n) {
    final kids = n.children.map(toIr).toList();
    switch (n.type) {
      case 'pass':
        return IRNode(
            type: 'passthrough', renderType: 'RenderView', children: kids);
      case 'para':
        // A reclassified para reuses the same id; needs a textId. Empty text
        // emits no text node (the encoder skips it) — fine.
        return IRNode(
          type: 'paragraph',
          renderType: 'RenderParagraph',
          bounds: _r(n.id, n.v),
          id: n.id,
          textId: n.textId ?? (n.id + 100000),
          text: n.text,
          style: IRStyle(backgroundColor: 'rgb(${n.v},0,0)'),
          children: kids,
        );
      default:
        return IRNode(
          type: 'box',
          renderType: 'RenderBox',
          bounds: _r(n.id, n.v),
          id: n.id,
          style: IRStyle(backgroundColor: 'rgb(${n.v},0,0)'),
          children: kids,
        );
    }
  }
}
