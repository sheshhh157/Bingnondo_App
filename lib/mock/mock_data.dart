// ─── MOCK FLAG ────────────────────────────────────────────────────────────────
const bool kUseMock = true;

// ─── Mock Credentials ──────────────────────────────────────────────────────────
const String kMockEmail    = 'test@bingnondo.com';
const String kMockPassword = 'Test1234';

// ─── Mock Tokens ───────────────────────────────────────────────────────────────
const String kMockAccessToken  = 'mock_access_token_dev';
const String kMockRefreshToken = 'mock_refresh_token_dev';

// ─── Mock User ─────────────────────────────────────────────────────────────────
const Map<String, dynamic> kMockUser = {
  'id': 1,
  'email': kMockEmail,
  'email_verified': true,
  'profile_completed': true,
  'status': 'active',
  'first_name': 'Juan',
  'last_name': 'dela Cruz',
};

// ─── Mock Customer Profile ─────────────────────────────────────────────────────
// Toggle restriction_level / profile_completed to test different gate states
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

// ─── Mock Order Response (POST /api/orders) ────────────────────────────────────
const Map<String, dynamic> kMockOrderResponse = {
  'id': 1001,
  'order_number': 'BNG-20260907-0042',
  'status': 'pending',
  'total_amount': 330.00,
  'payment_url': null,
};

// ─── Mock Order Detail (GET /api/orders/:id) ───────────────────────────────────
// Change 'status' to test different timeline positions:
//   'pending' | 'confirmed' | 'preparing' | 'ready'
//   | 'out_for_delivery' | 'completed' | 'cancelled'
const Map<String, dynamic> kMockOrderDetail = {
  'id': 1001,
  'order_number': 'BNG-20260907-0042',
  'status': 'preparing', // <-- change this to test different states
  'payment_method': 'gcash',
  'total_amount': 330.00,
  'notes': 'Extra chili garlic for siomai please!',
  'created_at': '2026-09-07T10:30:00.000Z',
  'updated_at': '2026-09-07T10:35:00.000Z',
  'items': [
    {
      'menu_item_id': 102,
      'name': 'Siomai de Binondo',
      'quantity': 2,
      'unit_price': 85.00,
      'note': 'Extra chili garlic',
    },
    {
      'menu_item_id': 201,
      'name': 'Lomi Binondo',
      'quantity': 1,
      'unit_price': 145.00,
      'note': null,
    },
    {
      'menu_item_id': 401,
      'name': 'Salted Caramel Milk Tea',
      'quantity': 1,
      'unit_price': 85.00,
      'note': null,
    },
  ],
  'delivery': {
    'preference': 'own_delivery',
    'status': 'pending_assignment',
    'rider_name': null,
    'rider_contact': null,
    'lalamove_booking_id': null,
  },
};

// ─── Mock Support Chat (GET /api/support-chat) ────────────────────────────────
// Set 'status' to 'locked' to test the locked state (no active orders)
const Map<String, dynamic> kMockSupportChat = {
  'id': 1,
  'status': 'unlocked', // 'unlocked' | 'locked'
  'active_order_id': 1001,
  'messages': [
    {
      'id': 1,
      'content': 'Hi! Just want to ask — is my order already being prepared?',
      'sender_type': 'customer',
      'related_order_id': 1001,
      'sent_at': '2026-09-07T10:31:00.000Z',
      'is_read': true,
    },
    {
      'id': 2,
      'content': 'Hi Juan! Yes, your order is already being prepared. Estimated 15–20 minutes.',
      'sender_type': 'staff',
      'related_order_id': 1001,
      'sent_at': '2026-09-07T10:33:00.000Z',
      'is_read': true,
    },
    {
      'id': 3,
      'content': 'Thank you! Can I add extra sauce?',
      'sender_type': 'customer',
      'related_order_id': 1001,
      'sent_at': '2026-09-07T10:34:00.000Z',
      'is_read': true,
    },
  ],
};

// ─── Mock Staff Reply Logic (for chatbot-style stub in dev) ───────────────────
String kMockStaffReply(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('ready') || lower.contains('tapos') || lower.contains('done')) {
    return 'Hi! Your order is still being prepared. We\'ll notify you once it\'s ready for pickup or delivery.';
  }
  if (lower.contains('cancel')) {
    return 'We\'ll check on that for you. Please note that once your order is being prepared, cancellation may not be possible.';
  }
  if (lower.contains('rider') || lower.contains('deliver') || lower.contains('driver')) {
    return 'A rider will be assigned once your food is ready. We\'ll send you their details shortly!';
  }
  if (lower.contains('sauce') || lower.contains('extra') || lower.contains('add')) {
    return 'We\'ll note that request and pass it to the kitchen. Thanks for letting us know!';
  }
  if (lower.contains('how long') || lower.contains('time') || lower.contains('wait')) {
    return 'Your order should be ready in about 15–20 minutes. We\'ll keep you posted!';
  }
  return 'Thanks for reaching out! We\'ll attend to your concern shortly. Is there anything else we can help you with?';
}

// ─── Mock Menu Data ────────────────────────────────────────────────────────────
const Map<String, dynamic> kMockMenuData = {
  'categories': [
    {'id': 1, 'name': 'Dimsum',     'description': 'Steamed & fried',  'sort_order': 1},
    {'id': 2, 'name': 'Noodles',    'description': 'Hot soups & pancit','sort_order': 2},
    {'id': 3, 'name': 'Rice Meals', 'description': 'Silog & ulam',      'sort_order': 3},
    {'id': 4, 'name': 'Drinks',     'description': 'Hot & cold',         'sort_order': 4},
    {'id': 5, 'name': 'Merienda',   'description': 'Light bites',        'sort_order': 5},
  ],
  'items': [
    {'id':101,'category_id':1,'name':'Hakaw (Shrimp Dumpling)','description':'Classic steamed shrimp dumpling.','price':95.00,'photo_url':null,'is_available':true},
    {'id':102,'category_id':1,'name':'Siomai de Binondo','description':'Pork & shrimp siomai. Served with chili garlic oil.','price':85.00,'photo_url':null,'is_available':true},
    {'id':103,'category_id':1,'name':'Asado Siopao','description':'Soft fluffy bun with sweet BBQ pork asado.','price':75.00,'photo_url':null,'is_available':true},
    {'id':104,'category_id':1,'name':'Beef Tripe (Goto Dimsum)','description':'Tender braised beef tripe, hoisin sauce.','price':110.00,'photo_url':null,'is_available':false},
    {'id':105,'category_id':1,'name':'Turnip Cake (Loh Bak Go)','description':'Pan-fried radish cake — crispy outside, soft inside.','price':90.00,'photo_url':null,'is_available':true},
    {'id':106,'category_id':1,'name':'Chicken Feet (Adidas)','description':'Black bean braised chicken feet.','price':95.00,'photo_url':null,'is_available':true},
    {'id':201,'category_id':2,'name':'Lomi Binondo','description':'Thick egg noodles in rich pork broth.','price':145.00,'photo_url':null,'is_available':true},
    {'id':202,'category_id':2,'name':'Pancit Canton Special','description':'Stir-fried egg noodles with vegetables, pork, shrimp.','price':160.00,'photo_url':null,'is_available':true},
    {'id':203,'category_id':2,'name':'La Paz Batchoy','description':'Miki noodles in pork broth with chicharron.','price':155.00,'photo_url':null,'is_available':true},
    {'id':204,'category_id':2,'name':'Wonton Mami','description':'Egg noodle soup with handmade wontons.','price':130.00,'photo_url':null,'is_available':false},
    {'id':301,'category_id':3,'name':'Asado Rice Plate','description':'Slow-braised pork asado on jasmine rice.','price':175.00,'photo_url':null,'is_available':true},
    {'id':302,'category_id':3,'name':'Yang Chow Fried Rice','description':'Classic fried rice with shrimp, char siu, egg.','price':165.00,'photo_url':null,'is_available':true},
    {'id':303,'category_id':3,'name':'Beef Ampalaya with Rice','description':'Beef with bitter melon and black bean sauce.','price':185.00,'photo_url':null,'is_available':true},
    {'id':401,'category_id':4,'name':'Salted Caramel Milk Tea','description':'HK-style milk tea with salted caramel and pearls.','price':85.00,'photo_url':null,'is_available':true},
    {'id':402,'category_id':4,'name':"Sago't Gulaman",'description':'Classic iced drink with sago, jelly, and arnibal.','price':55.00,'photo_url':null,'is_available':true},
    {'id':403,'category_id':4,'name':'Wintermelon Milk Tea','description':'Smooth wintermelon tea with milk foam.','price':90.00,'photo_url':null,'is_available':true},
    {'id':404,'category_id':4,'name':'Hot Ginger Tea','description':'Warming fresh-grated ginger tea.','price':45.00,'photo_url':null,'is_available':true},
    {'id':501,'category_id':5,'name':'Egg Tart (Dan Tat)','description':'Flaky pastry with silky egg custard. 2 pcs.','price':65.00,'photo_url':null,'is_available':true},
    {'id':502,'category_id':5,'name':'Sesame Balls (Buchi)','description':'Glutinous rice balls with red bean filling.','price':70.00,'photo_url':null,'is_available':true},
    {'id':503,'category_id':5,'name':'Pineapple Cake','description':'Buttery pastry filled with pineapple jam.','price':55.00,'photo_url':null,'is_available':false},
  ],
};

// ─── Mock Chatbot Replies ──────────────────────────────────────────────────────
final List<Map<String, dynamic>> kMockBotReplies = [
  {'keywords':['available','open','may'],'reply':"Nandito kami at bukas ngayon! Most items are available — only Beef Tripe, Wonton Mami, and Pineapple Cake are sold out for today."},
  {'keywords':['vegetarian','vegan','gulay'],'reply':"Veggie-friendly options: Turnip Cake, Sago't Gulaman, Hot Ginger Tea, and Egg Tart."},
  {'keywords':['bestseller','popular','recommend','best'],'reply':"Our bestsellers: Siomai de Binondo (₱85), Lomi Binondo (₱145), Yang Chow Fried Rice (₱165)."},
  {'keywords':['delivery','deliver','padala','fee'],'reply':"Delivery fees shown at checkout. We deliver within Metro Manila. Minimum order ₱300."},
  {'keywords':['close','bukas','oras','time','hours'],'reply':"Open daily 7:00 AM – 9:00 PM. Last order at 8:30 PM."},
  {'keywords':['price','magkano','how much'],'reply':"Prices range from ₱45 (Hot Ginger Tea) to ₱185 (Beef Ampalaya Rice)."},
  {'keywords':['siomai','hakaw','dimsum','dumpling'],'reply':"Siomai de Binondo ₱85 and Hakaw ₱95 — both available now!"},
  {'keywords':['lomi','noodle','mami','pancit'],'reply':"Lomi Binondo (₱145), Pancit Canton Special (₱160), La Paz Batchoy (₱155) — all available!"},
  {'keywords':['milk tea','tea','drink','inumin'],'reply':"Salted Caramel Milk Tea (₱85), Wintermelon Milk Tea (₱90), Sago't Gulaman (₱55), Hot Ginger Tea (₱45)."},
];

String getMockBotReply(String message) {
  final lower = message.toLowerCase();
  for (final entry in kMockBotReplies) {
    final keywords = entry['keywords'] as List<String>;
    if (keywords.any((k) => lower.contains(k))) return entry['reply'] as String;
  }
  return "Hmm, I'm not sure about that. Try asking about our menu, bestsellers, hours, or delivery!";
}

// Add this to your existing mock_data.dart
// kMockOrderList — list of orders for My Orders screen (GET /api/orders)

const List<Map<String, dynamic>> kMockOrderList = [
  // Active order — currently being prepared
  {
    'id': 1001,
    'order_number': 'BNG-20260907-0042',
    'status': 'preparing',
    'total_amount': 330.00,
    'item_count': 4,
    'payment_method': 'gcash',
    'created_at': '2026-09-07T10:30:00.000Z',
  },
  // Past order — completed
  {
    'id': 998,
    'order_number': 'BNG-20260905-0039',
    'status': 'completed',
    'total_amount': 245.00,
    'item_count': 3,
    'payment_method': 'cod',
    'created_at': '2026-09-05T12:15:00.000Z',
  },
  // Past order — completed
  {
    'id': 991,
    'order_number': 'BNG-20260901-0031',
    'status': 'completed',
    'total_amount': 490.00,
    'item_count': 6,
    'payment_method': 'gcash',
    'created_at': '2026-09-01T18:45:00.000Z',
  },
  // Past order — cancelled
  {
    'id': 985,
    'order_number': 'BNG-20260828-0025',
    'status': 'cancelled',
    'total_amount': 155.00,
    'item_count': 1,
    'payment_method': 'cod',
    'created_at': '2026-08-28T09:00:00.000Z',
  },
];