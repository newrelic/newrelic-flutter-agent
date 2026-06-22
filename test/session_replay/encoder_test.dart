/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/src/session_replay/ir/ir_node.dart';
import 'package:newrelic_mobile/src/session_replay/ir/ir_style.dart';
import 'package:newrelic_mobile/src/session_replay/rrweb/full_snapshot_builder.dart';

/// Depth-first search for the first element node matching [test].
Map<String, dynamic>? findEl(
  Map<String, dynamic> node,
  bool Function(Map<String, dynamic>) test,
) {
  if (test(node)) return node;
  for (final c in (node['childNodes'] as List? ?? const [])) {
    final r = findEl(c as Map<String, dynamic>, test);
    if (r != null) return r;
  }
  return null;
}

/// All element nodes matching [test], in document order.
List<Map<String, dynamic>> findAllEl(
  Map<String, dynamic> node,
  bool Function(Map<String, dynamic>) test,
) {
  final out = <Map<String, dynamic>>[];
  void walk(Map<String, dynamic> n) {
    if (test(n)) out.add(n);
    for (final c in (n['childNodes'] as List? ?? const [])) {
      walk(c as Map<String, dynamic>);
    }
  }

  walk(node);
  return out;
}

String styleOf(Map<String, dynamic> el) =>
    (el['attributes'] as Map)['style'] as String? ?? '';

void main() {
  Map<String, dynamic> encode(IRNode ir, {int timestamp = 0}) =>
      FullSnapshotBuilder().build(ir, timestamp: timestamp).toJson();

  group('document wrapper', () {
    test('wraps content in document > html > head/body with doctype', () {
      final ir = IRNode(
        type: 'box',
        renderType: 'Root',
        bounds: const IRRect(0, 0, 400, 800),
      );
      final json = encode(ir, timestamp: 123);

      expect(json['type'], 2); // FullSnapshot
      expect(json['timestamp'], 123);
      expect(json['data']['initialOffset'], {'left': 0, 'top': 0});

      final doc = json['data']['node'] as Map<String, dynamic>;
      expect(doc['type'], 0); // document

      final docKids = doc['childNodes'] as List;
      expect(docKids[0]['type'], 1); // doctype
      expect(docKids[0]['name'], 'html');

      final html = docKids[1] as Map<String, dynamic>;
      expect(html['tagName'], 'html');
      final head = html['childNodes'][0] as Map<String, dynamic>;
      final body = html['childNodes'][1] as Map<String, dynamic>;
      expect(head['tagName'], 'head');
      expect(body['tagName'], 'body');
    });

    test('head style carries the viewport dimensions', () {
      final ir = IRNode(
        type: 'box',
        renderType: 'Root',
        bounds: const IRRect(0, 0, 411, 914),
      );
      final json = encode(ir);
      final style = findEl(json['data']['node'] as Map<String, dynamic>,
          (n) => n['tagName'] == 'style')!;
      final css = (style['childNodes'] as List).first['textContent'] as String;
      expect(css, contains('width:411px'));
      expect(css, contains('height:914px'));
    });

    test('viewport is derived from the first laid-out descendant', () {
      // Root is a passthrough (no bounds); first laid-out child is 360x640.
      final ir = IRNode(
        type: 'passthrough',
        renderType: 'RenderView',
        children: [
          IRNode(
            type: 'box',
            renderType: 'Root',
            bounds: const IRRect(0, 0, 360, 640),
          ),
        ],
      );
      final json = encode(ir);
      final style = findEl(json['data']['node'] as Map<String, dynamic>,
          (n) => n['tagName'] == 'style')!;
      final css = (style['childNodes'] as List).first['textContent'] as String;
      expect(css, contains('width:360px'));
      expect(css, contains('height:640px'));
    });
  });

  group('node classification', () {
    Map<String, dynamic> bodyOf(Map<String, dynamic> json) => findEl(
        json['data']['node'] as Map<String, dynamic>,
        (n) => n['tagName'] == 'body')!;

    test('paragraph becomes div.nr-text with a text child', () {
      final ir = IRNode(
        type: 'box',
        renderType: 'Root',
        bounds: const IRRect(0, 0, 400, 800),
        children: [
          IRNode(
            type: 'paragraph',
            renderType: 'RenderParagraph',
            bounds: const IRRect(10, 20, 100, 30),
            text: 'Hello',
            style: const IRStyle(color: 'rgb(0,0,0)', fontSize: '14.0px'),
          ),
        ],
      );
      final p = findEl(bodyOf(encode(ir)),
          (n) => (n['attributes'] as Map?)?['class'] == 'nr-text')!;
      expect(p['tagName'], 'div');
      final textChild = (p['childNodes'] as List).first;
      expect(textChild['type'], 3); // text node
      expect(textChild['textContent'], 'Hello');
      expect(styleOf(p), contains('color:rgb(0,0,0)'));
      expect(styleOf(p), contains('font-size:14.0px'));
    });

    test('icon becomes div.nr-icon with its glyph text', () {
      final ir = IRNode(
        type: 'box',
        renderType: 'Root',
        bounds: const IRRect(0, 0, 400, 800),
        children: [
          IRNode(
            type: 'icon',
            renderType: 'RenderParagraph',
            bounds: const IRRect(0, 0, 24, 24),
            text: '',
          ),
        ],
      );
      final icon = findEl(bodyOf(encode(ir)),
          (n) => (n['attributes'] as Map?)?['class'] == 'nr-icon')!;
      expect((icon['childNodes'] as List).first['textContent'], '');
    });

    test('image becomes an img element', () {
      final ir = IRNode(
        type: 'box',
        renderType: 'Root',
        bounds: const IRRect(0, 0, 400, 800),
        children: [
          IRNode(
            type: 'image',
            renderType: 'RenderImage',
            bounds: const IRRect(0, 0, 50, 50),
          ),
        ],
      );
      final img =
          findEl(bodyOf(encode(ir)), (n) => n['tagName'] == 'img');
      expect(img, isNotNull);
    });

    test('box decoration styles are emitted', () {
      final ir = IRNode(
        type: 'box',
        renderType: 'Root',
        bounds: const IRRect(0, 0, 400, 800),
        children: [
          IRNode(
            type: 'box',
            renderType: 'RenderDecoratedBox',
            bounds: const IRRect(0, 0, 100, 40),
            style: const IRStyle(
              backgroundColor: 'rgb(255,0,0)',
              border: '1.0px solid rgb(0,0,0)',
              borderRadius: '4.0px',
            ),
          ),
        ],
      );
      final body = bodyOf(encode(ir));
      final styled = findAllEl(body, (n) => n['tagName'] == 'div')
          .map(styleOf)
          .firstWhere((s) => s.contains('background-color'));
      expect(styled, contains('background-color:rgb(255,0,0)'));
      expect(styled, contains('border:1.0px solid rgb(0,0,0)'));
      expect(styled, contains('border-radius:4.0px'));
    });
  });

  group('layout', () {
    test('child coordinates are parent-local, not global (regression)', () {
      // root(0,0) > box(50,60) > paragraph(70,90 global) => local (20,30)
      final ir = IRNode(
        type: 'box',
        renderType: 'Root',
        bounds: const IRRect(0, 0, 400, 800),
        children: [
          IRNode(
            type: 'box',
            renderType: 'Mid',
            bounds: const IRRect(50, 60, 300, 300),
            children: [
              IRNode(
                type: 'paragraph',
                renderType: 'RenderParagraph',
                bounds: const IRRect(70, 90, 100, 20),
                text: 'X',
              ),
            ],
          ),
        ],
      );
      final p = findEl(json(ir), (n) => (n['attributes'] as Map?)?['class'] == 'nr-text')!;
      expect(styleOf(p), contains('left:20.0px'));
      expect(styleOf(p), contains('top:30.0px'));
      expect(styleOf(p), contains('width:100.0px'));
      expect(styleOf(p), contains('height:20.0px'));
    });

    test('passthrough nodes (no bounds) flatten — no wrapper div emitted', () {
      final ir = IRNode(
        type: 'passthrough',
        renderType: 'RenderView',
        children: [
          IRNode(
            type: 'box',
            renderType: 'A',
            bounds: const IRRect(0, 0, 100, 100),
          ),
          IRNode(
            type: 'box',
            renderType: 'B',
            bounds: const IRRect(200, 200, 50, 50),
          ),
        ],
      );
      final body = findEl(json(ir), (n) => n['tagName'] == 'body')!;
      // Both boxes promoted directly into body; passthrough produced no node.
      expect((body['childNodes'] as List).length, 2);
    });

    test('a passthrough between two boxes preserves the coordinate base', () {
      // root(0,0) > passthrough > box(50,60) > paragraph(70,90) => local (20,30)
      final ir = IRNode(
        type: 'box',
        renderType: 'Root',
        bounds: const IRRect(0, 0, 400, 800),
        children: [
          IRNode(
            type: 'passthrough',
            renderType: 'RenderTransform',
            children: [
              IRNode(
                type: 'box',
                renderType: 'Mid',
                bounds: const IRRect(50, 60, 300, 300),
                children: [
                  IRNode(
                    type: 'paragraph',
                    renderType: 'RenderParagraph',
                    bounds: const IRRect(70, 90, 10, 10),
                    text: 'Y',
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final p = findEl(json(ir), (n) => (n['attributes'] as Map?)?['class'] == 'nr-text')!;
      expect(styleOf(p), contains('left:20.0px'));
      expect(styleOf(p), contains('top:30.0px'));
    });
  });
}

/// Convenience: encode and return the document node JSON.
Map<String, dynamic> json(IRNode ir) =>
    FullSnapshotBuilder().build(ir, timestamp: 0).toJson()['data']['node']
        as Map<String, dynamic>;
