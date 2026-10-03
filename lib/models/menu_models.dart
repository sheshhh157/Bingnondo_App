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
    // Backend returns: { id, sender: 'customer'|'bot', content, sent_at }
    // 'sender' field: 'customer' maps to user, 'bot' maps to bot.
    // Falls back to 'role' key for forward compatibility.
    final senderRaw = json['sender'] as String? ?? json['role'] as String? ?? 'bot';
    final isSenderCustomer = senderRaw == 'customer' || senderRaw == 'user';
    final timestampRaw = json['sent_at'] as String? ?? json['created_at'] as String?;
    return ChatMessage(
      id: json['id'].toString(),
      content: json['content'] as String,
      sender: isSenderCustomer ? MessageSender.user : MessageSender.bot,
      timestamp: timestampRaw != null ? DateTime.parse(timestampRaw) : DateTime.now(),
    );
  }
}

class ChatHistory {
  final String conversationId;
  final List<ChatMessage> messages;

  const ChatHistory({required this.conversationId, required this.messages});

  factory ChatHistory.fromJson(Map<String, dynamic> json) {
    // Backend GET /api/chatbot/history returns:
    // { messages: [ { id, sender, content, sent_at, conversation_id } ] }
    // conversation_id may be absent at root level (it lives per-message row).
    final rawList = json['messages'] as List<dynamic>? ?? [];
    final msgs = rawList
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    // Derive conversationId from root or from the first message row
    final convId = json['conversation_id']?.toString() ??
        (rawList.isNotEmpty
            ? (rawList.first as Map<String, dynamic>)['conversation_id']?.toString()
            : null) ??
        '';
    return ChatHistory(
      conversationId: convId,
      messages: msgs,
    );
  }
}