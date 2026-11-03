// ─── Menu Models ──────────────────────────────────────────────────────────────

// ─── Variant Models ───────────────────────────────────────────────────────────

class MenuItemVariant {
  final int id;
  final int menuItemId;
  final String name;
  final double price;
  final bool isAvailable;
  final int displayOrder;
  final int? variantGroupId;

  const MenuItemVariant({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.isAvailable,
    required this.displayOrder,
    this.variantGroupId,
  });

  factory MenuItemVariant.fromJson(Map<String, dynamic> json) {
    return MenuItemVariant(
      id:             json['id'] as int,
      menuItemId:     json['menu_item_id'] as int? ?? 0,
      name:           json['name'] as String,
      price:          (json['price'] as num).toDouble(),
      isAvailable:    json['is_available'] as bool? ?? true,
      displayOrder:   json['display_order'] as int? ?? 0,
      variantGroupId: json['variant_group_id'] as int?,
    );
  }
}

class VariantGroup {
  final int id;
  final String name;
  final int maxOptions;
  final List<MenuItemVariant> variants;

  const VariantGroup({
    required this.id,
    required this.name,
    required this.maxOptions,
    required this.variants,
  });

  /// True when the customer MUST pick at least one option from this group.
  /// We treat max_options == 1 as a "required single-select" (e.g. Hot/Cold).
  bool get isRequired => maxOptions == 1;

  factory VariantGroup.fromJson(Map<String, dynamic> json) {
    final rawVariants = json['variants'] as List<dynamic>? ?? [];
    return VariantGroup(
      id:         json['id'] as int,
      name:       json['name'] as String,
      maxOptions: json['max_options'] as int? ?? 1,
      variants:   rawVariants
          .map((v) => MenuItemVariant.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

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
      // Backend sends 'display_order' (migration 006); fall back to legacy
      // 'sort_order' key so mock data still works during dev.
      sortOrder: json['display_order'] as int? ?? json['sort_order'] as int? ?? 0,
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
  // Variants for this item — empty list means no variants (direct add-to-cart).
  final List<MenuItemVariant> variants;
  // Variant groups — populated from the detail endpoint or nested in /menu.
  final List<VariantGroup> variantGroups;

  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.photoUrl,
    required this.isAvailable,
    this.variants = const [],
    this.variantGroups = const [],
  });

  /// True when this item has at least one available variant in any group.
  bool get hasVariants => variants.any((v) => v.isAvailable);

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // Parse flat variants list (used in /api/menu nested response)
    final rawVariants = json['variants'] as List<dynamic>? ?? [];
    final variantList = rawVariants
        .map((v) => MenuItemVariant.fromJson(v as Map<String, dynamic>))
        .toList();

    // Parse variant_groups (used in /api/menu/:id detail response)
    final rawGroups = json['variant_groups'] as List<dynamic>? ?? [];
    final groupList = rawGroups
        .map((g) => VariantGroup.fromJson(g as Map<String, dynamic>))
        .toList();

    return MenuItem(
      id: json['id'] as int,
      categoryId: json['category_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      // Backend sends 'image_url'; fall back to 'photo_url' so mock data works.
      photoUrl: json['image_url'] as String? ?? json['photo_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      variants:      variantList,
      variantGroups: groupList,
    );
  }

  MenuItem copyWith({
    bool? isAvailable,
    List<MenuItemVariant>? variants,
    List<VariantGroup>? variantGroups,
  }) {
    return MenuItem(
      id:             id,
      categoryId:     categoryId,
      name:           name,
      description:    description,
      price:          price,
      photoUrl:       photoUrl,
      isAvailable:    isAvailable ?? this.isAvailable,
      variants:       variants ?? this.variants,
      variantGroups:  variantGroups ?? this.variantGroups,
    );
  }

  /// Build grouped variant structure from the flat `variants` list.
  /// Used when variant_groups aren't returned (e.g. the list endpoint).
  List<VariantGroup> get inferredVariantGroups {
    if (variantGroups.isNotEmpty) return variantGroups;
    // Group by variantGroupId; ungrouped variants go under a default group.
    final Map<int?, List<MenuItemVariant>> grouped = {};
    for (final v in variants) {
      (grouped[v.variantGroupId] ??= []).add(v);
    }
    return grouped.entries.map((entry) {
      return VariantGroup(
        id:         entry.key ?? 0,
        name:       'Options',
        maxOptions: 1,
        variants:   entry.value,
      );
    }).toList();
  }
}

// Wraps both categories + items for the menu API response
class MenuData {
  final List<MenuCategory> categories;
  final List<MenuItem> items;

  const MenuData({required this.categories, required this.items});

  factory MenuData.fromJson(Map<String, dynamic> json) {
    // Backend (§ 1.3) returns items NESTED inside each category:
    //   { categories: [{ id, name, ..., items: [...] }] }
    //
    // Mock data uses a flat top-level 'items' list (legacy shape).
    // We support both: if a category has an 'items' key we use it;
    // otherwise we fall back to the top-level 'items' list.

    final rawCats = json['categories'] as List<dynamic>? ?? [];
    final bool isNested = rawCats.isNotEmpty &&
        (rawCats.first as Map<String, dynamic>).containsKey('items');

    List<MenuItem> allItems;

    if (isNested) {
      // Real backend shape: flatten items out of each category
      allItems = rawCats
          .expand((c) {
        final cat = c as Map<String, dynamic>;
        final catItems = cat['items'] as List<dynamic>? ?? [];
        return catItems.map((i) {
          final item = Map<String, dynamic>.from(i as Map<String, dynamic>);
          // Ensure category_id is present (it is in the backend response)
          item['category_id'] ??= cat['id'];
          return MenuItem.fromJson(item);
        });
      })
          .toList();
    } else {
      // Mock / legacy shape: items at top level
      allItems = (json['items'] as List<dynamic>? ?? [])
          .map((i) => MenuItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    final cats = rawCats
        .map((c) => MenuCategory.fromJson(c as Map<String, dynamic>))
        .toList();

    return MenuData(categories: cats, items: allItems);
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