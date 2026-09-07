// ─── Menu Models ──────────────────────────────────────────────────────────────

class MenuCategory {
  final int id;
  final String name;
  final String? description;
  final int sortOrder;

  const MenuCategory({
    required this.id,
    required this.name,
    this.description,
    required this.sortOrder,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class MenuItem {
  final int id;
  final int categoryId;
  final String name;
  final String? description;
  final double price;
  final String? photoUrl;
  final bool isAvailable;

  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.photoUrl,
    required this.isAvailable,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as int,
      categoryId: json['category_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      photoUrl: json['photo_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  MenuItem copyWith({bool? isAvailable}) {
    return MenuItem(
      id: id,
      categoryId: categoryId,
      name: name,
      description: description,
      price: price,
      photoUrl: photoUrl,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

// Wraps both categories + items for the menu API response
class MenuData {
  final List<MenuCategory> categories;
  final List<MenuItem> items;

  const MenuData({required this.categories, required this.items});

  factory MenuData.fromJson(Map<String, dynamic> json) {
    final cats = (json['categories'] as List<dynamic>? ?? [])
        .map((c) => MenuCategory.fromJson(c as Map<String, dynamic>))
        .toList();
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((i) => MenuItem.fromJson(i as Map<String, dynamic>))
        .toList();
    return MenuData(categories: cats, items: items);
  }

  List<MenuItem> itemsForCategory(int categoryId) =>
      items.where((i) => i.categoryId == categoryId).toList();
}

// ─── Chatbot Models ────────────────────────────────────────────────────────────

enum MessageSender { user, bot }

class ChatMessage {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final bool isLoading;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.isLoading = false,
  });

  factory ChatMessage.user(String content) => ChatMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    content: content,
    sender: MessageSender.user,
    timestamp: DateTime.now(),
  );

  factory ChatMessage.botLoading() => ChatMessage(
    id: 'loading',
    content: '',
    sender: MessageSender.bot,
    timestamp: DateTime.now(),
    isLoading: true,
  );

  factory ChatMessage.bot(String content) => ChatMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    content: content,
    sender: MessageSender.bot,
    timestamp: DateTime.now(),
  );

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'].toString(),
      content: json['content'] as String,
      sender: json['role'] == 'user' ? MessageSender.user : MessageSender.bot,
      timestamp: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ChatHistory {
  final String conversationId;
  final List<ChatMessage> messages;

  const ChatHistory({required this.conversationId, required this.messages});

  factory ChatHistory.fromJson(Map<String, dynamic> json) {
    final msgs = (json['messages'] as List<dynamic>? ?? [])
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    return ChatHistory(
      conversationId: json['conversation_id'].toString(),
      messages: msgs,
    );
  }
}