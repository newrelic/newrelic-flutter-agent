class SerializedNode {
  static const int document = 0;
  static const int documentType = 1;
  static const int element = 2;
  static const int text = 3;

  final int type;
  final int id;
  final String? tagName;
  final Map<String, String>? attributes;
  final List<SerializedNode>? childNodes;
  final String? textContent;
  final String? name;
  final String? publicId;
  final String? systemId;

  const SerializedNode._({
    required this.type,
    required this.id,
    this.tagName,
    this.attributes,
    this.childNodes,
    this.textContent,
    this.name,
    this.publicId,
    this.systemId,
  });

  factory SerializedNode.documentNode({
    required int id,
    required List<SerializedNode> childNodes,
  }) =>
      SerializedNode._(type: document, id: id, childNodes: childNodes);

  factory SerializedNode.documentTypeNode({
    required int id,
    required String name,
  }) =>
      SerializedNode._(
        type: documentType,
        id: id,
        name: name,
        publicId: '',
        systemId: '',
      );

  factory SerializedNode.elementNode({
    required int id,
    required String tagName,
    Map<String, String> attributes = const {},
    List<SerializedNode> childNodes = const [],
  }) =>
      SerializedNode._(
        type: element,
        id: id,
        tagName: tagName,
        attributes: attributes,
        childNodes: childNodes,
      );

  factory SerializedNode.textNode({
    required int id,
    required String textContent,
  }) =>
      SerializedNode._(type: text, id: id, textContent: textContent);

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'type': type, 'id': id};
    if (tagName != null) m['tagName'] = tagName;
    if (attributes != null) m['attributes'] = attributes;
    if (childNodes != null) {
      m['childNodes'] = childNodes!.map((n) => n.toJson()).toList();
    }
    if (textContent != null) m['textContent'] = textContent;
    if (name != null) m['name'] = name;
    if (publicId != null) m['publicId'] = publicId;
    if (systemId != null) m['systemId'] = systemId;
    return m;
  }
}
