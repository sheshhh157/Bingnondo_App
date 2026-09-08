// ─── MOCK FLAG ────────────────────────────────────────────────────────────────
// Set to true during local development/testing (no backend needed).
// Set to false before pushing to staging/production.
const bool kUseMock = true;

// ─── Mock Credentials ──────────────────────────────────────────────────────────
const String kMockEmail = 'test@bingnondo.com';
const String kMockPassword = 'Test1234';

// ─── Mock Token ────────────────────────────────────────────────────────────────
const String kMockAccessToken = 'mock_access_token_dev';
const String kMockRefreshToken = 'mock_refresh_token_dev';

// ─── Mock User ─────────────────────────────────────────────────────────────────
const Map<String, dynamic> kMockUser = {
  'id': 1,
  'email': kMockEmail,
  'email_verified': true,
  'profile_completed': true, // set true so cart gate passes
  'status': 'active',
  'first_name': 'Juan',
  'last_name': 'dela Cruz',
};

// ─── Mock Customer Profile (for cart gate check) ───────────────────────────────
// Toggle profile_completed / restriction_level to test different states:
//   profile_completed: false  → redirects to Complete Profile
//   restriction_level: 'cod_restricted' → hides COD option
//   restriction_level: 'suspended' → blocks checkout entirely
const Map<String, dynamic> kMockProfile = {
  'id': 1,
  'email': kMockEmail,
  'profile_completed': true,
  'first_name': 'Juan',
  'last_name': 'dela Cruz',
  'mobile_number': '+639171234567',
  'address': '123 Ongpin St, Binondo, Manila',
  'restriction_level': 'none', // 'none' | 'warned' | 'cod_restricted' | 'suspended'
};

// ─── Mock Order Response ───────────────────────────────────────────────────────
const Map<String, dynamic> kMockOrderResponse = {
  'id': 1001,
  'order_number': 'BNG-20260907-0042',
  'status': 'pending',
  'total_amount': 330.00,
  'payment_url': null, // set a URL string to test GCash webview redirect
};

// ─── Mock Menu Data ────────────────────────────────────────────────────────────
const Map<String, dynamic> kMockMenuData = {
  'categories': [
    {'id': 1, 'name': 'Dimsum', 'description': 'Steamed & fried', 'sort_order': 1},
    {'id': 2, 'name': 'Noodles', 'description': 'Hot soups & pancit', 'sort_order': 2},
    {'id': 3, 'name': 'Rice Meals', 'description': 'Silog & ulam', 'sort_order': 3},
    {'id': 4, 'name': 'Drinks', 'description': 'Hot & cold', 'sort_order': 4},
    {'id': 5, 'name': 'Merienda', 'description': 'Light bites', 'sort_order': 5},
  ],
  'items': [
    // ── Dimsum ─────────────────────────────────────────────────────────────
    {
      'id': 101, 'category_id': 1, 'name': 'Hakaw (Shrimp Dumpling)',
      'description': 'Classic steamed shrimp dumpling wrapped in translucent rice flour skin.',
      'price': 95.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 102, 'category_id': 1, 'name': 'Siomai de Binondo',
      'description': 'Pork & shrimp siomai steamed to perfection. Served with chili garlic oil.',
      'price': 85.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 103, 'category_id': 1, 'name': 'Asado Siopao',
      'description': 'Soft fluffy bun stuffed with sweet BBQ pork asado filling.',
      'price': 75.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 104, 'category_id': 1, 'name': 'Beef Tripe (Goto Dimsum)',
      'description': 'Tender braised beef tripe served with hoisin dipping sauce.',
      'price': 110.00, 'photo_url': null, 'is_available': false,
    },
    {
      'id': 105, 'category_id': 1, 'name': 'Turnip Cake (Loh Bak Go)',
      'description': 'Pan-fried radish cake — crispy outside, soft and savory inside.',
      'price': 90.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 106, 'category_id': 1, 'name': 'Chicken Feet (Adidas)',
      'description': 'Black bean braised chicken feet, Binondo style.',
      'price': 95.00, 'photo_url': null, 'is_available': true,
    },
    // ── Noodles ────────────────────────────────────────────────────────────
    {
      'id': 201, 'category_id': 2, 'name': 'Lomi Binondo',
      'description': 'Thick egg noodles in rich pork broth with kikiam, squid balls, and egg.',
      'price': 145.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 202, 'category_id': 2, 'name': 'Pancit Canton Special',
      'description': 'Stir-fried egg noodles with mixed vegetables, pork, and shrimp.',
      'price': 160.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 203, 'category_id': 2, 'name': 'La Paz Batchoy',
      'description': 'Miki noodles in pork broth topped with chicharron, liver, and egg.',
      'price': 155.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 204, 'category_id': 2, 'name': 'Wonton Mami',
      'description': 'Egg noodle soup with handmade pork & shrimp wontons.',
      'price': 130.00, 'photo_url': null, 'is_available': false,
    },
    // ── Rice Meals ─────────────────────────────────────────────────────────
    {
      'id': 301, 'category_id': 3, 'name': 'Asado Rice Plate',
      'description': 'Slow-braised pork asado on steamed jasmine rice with bok choy.',
      'price': 175.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 302, 'category_id': 3, 'name': 'Yang Chow Fried Rice',
      'description': 'Classic Chinese fried rice with shrimp, char siu, and egg.',
      'price': 165.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 303, 'category_id': 3, 'name': 'Beef Ampalaya with Rice',
      'description': 'Tender beef strips stir-fried with bitter melon and black bean sauce.',
      'price': 185.00, 'photo_url': null, 'is_available': true,
    },
    // ── Drinks ─────────────────────────────────────────────────────────────
    {
      'id': 401, 'category_id': 4, 'name': 'Salted Caramel Milk Tea',
      'description': 'Hong Kong-style milk tea with salted caramel and tapioca pearls.',
      'price': 85.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 402, 'category_id': 4, 'name': "Sago't Gulaman",
      'description': 'Classic Filipino iced drink with sago pearls, jelly, and arnibal syrup.',
      'price': 55.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 403, 'category_id': 4, 'name': 'Wintermelon Milk Tea',
      'description': 'Smooth wintermelon tea with creamy milk foam and pearls.',
      'price': 90.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 404, 'category_id': 4, 'name': 'Hot Ginger Tea',
      'description': 'Warming fresh-grated ginger tea — perfect after dimsum.',
      'price': 45.00, 'photo_url': null, 'is_available': true,
    },
    // ── Merienda ───────────────────────────────────────────────────────────
    {
      'id': 501, 'category_id': 5, 'name': 'Egg Tart (Dan Tat)',
      'description': 'Flaky pastry shell with silky smooth egg custard filling. 2 pcs.',
      'price': 65.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 502, 'category_id': 5, 'name': 'Sesame Balls (Buchi)',
      'description': 'Deep-fried glutinous rice balls coated in sesame seeds with red bean filling.',
      'price': 70.00, 'photo_url': null, 'is_available': true,
    },
    {
      'id': 503, 'category_id': 5, 'name': 'Pineapple Cake',
      'description': 'Buttery shortbread-style pastry filled with pineapple jam. Taiwanese-style.',
      'price': 55.00, 'photo_url': null, 'is_available': false,
    },
  ],
};

// ─── Mock Chatbot Replies ──────────────────────────────────────────────────────
final List<Map<String, dynamic>> kMockBotReplies = [
  {
    'keywords': ['available', 'open', 'may'],
    'reply': 'Nandito kami at bukas ngayon! Most items are available — only the Beef Tripe, Wonton Mami, and Pineapple Cake are sold out for today.',
  },
  {
    'keywords': ['vegetarian', 'vegan', 'gulay', 'meat-free'],
    'reply': "We have a few veggie-friendly options: Turnip Cake (Loh Bak Go), Sago't Gulaman, Hot Ginger Tea, and Egg Tart.",
  },
  {
    'keywords': ['bestseller', 'popular', 'recommend', 'best'],
    'reply': 'Our bestsellers are the Siomai de Binondo (₱85), Lomi Binondo (₱145), and the Yang Chow Fried Rice (₱165).',
  },
  {
    'keywords': ['delivery', 'deliver', 'padala', 'fee'],
    'reply': 'Delivery fees depend on your location and are shown at checkout. We deliver within Metro Manila. Minimum order of ₱300.',
  },
  {
    'keywords': ['close', 'bukas', 'oras', 'time', 'hours', 'schedule'],
    'reply': "We're open daily from 7:00 AM to 9:00 PM. Kitchen last order is at 8:30 PM.",
  },
  {
    'keywords': ['price', 'magkano', 'cost', 'how much'],
    'reply': 'Our prices range from ₱45 for Hot Ginger Tea up to ₱185 for Beef Ampalaya Rice.',
  },
  {
    'keywords': ['siomai', 'hakaw', 'dimsum', 'dumpling'],
    'reply': 'Our Siomai de Binondo is ₱85 and the Hakaw (Shrimp Dumpling) is ₱95 — both available now!',
  },
  {
    'keywords': ['lomi', 'noodle', 'mami', 'pancit'],
    'reply': 'Lomi Binondo (₱145) is our most-ordered noodle dish. Pancit Canton Special (₱160) and La Paz Batchoy (₱155) are also available!',
  },
  {
    'keywords': ['milk tea', 'tea', 'drink', 'inumin'],
    'reply': 'We have Salted Caramel Milk Tea (₱85), Wintermelon Milk Tea (₱90), Sago\'t Gulaman (₱55), and Hot Ginger Tea (₱45).',
  },
];

String getMockBotReply(String message) {
  final lower = message.toLowerCase();
  for (final entry in kMockBotReplies) {
    final keywords = entry['keywords'] as List<String>;
    if (keywords.any((k) => lower.contains(k))) {
      return entry['reply'] as String;
    }
  }
  return "Hmm, I'm not sure about that. Try asking about our menu, bestsellers, hours, or delivery!";
}