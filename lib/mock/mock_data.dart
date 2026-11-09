// ─── MOCK FLAG ────────────────────────────────────────────────────────────────
const bool kUseMock = false;

// ─── Mock Credentials ──────────────────────────────────────────────────────────
const String kMockEmail    = 'test@bingnondo.com';
const String kMockPassword = 'Test1234';
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

// ─── Mock Customer Profile (cart gate check) ───────────────────────────────────
const Map<String, dynamic> kMockProfile = {
  'id': 1,
  'email': kMockEmail,
  'profile_completed': true,
  'first_name': 'Juan',
  'last_name': 'dela Cruz',
  'mobile_number': '+639171234567',
  'address': 'Poblacion, Santa Cruz, Laguna',
  'latitude': 14.2818,
  'longitude': 121.4149,
  'restriction_level': 'none',
};

// ─── Mock Account Profile (§1.9 settings) ─────────────────────────────────────
const Map<String, dynamic> kMockAccountProfile = {
  'id': 1,
  'email': kMockEmail,
  'first_name': 'Juan',
  'last_name': 'dela Cruz',
  'mobile_number': '+639171234567',
  'address': 'Poblacion, Santa Cruz, Laguna',
  'latitude': 14.2818,
  'longitude': 121.4149,
  'profile_completed': true,
  'has_saved_payment': true,
  'saved_payment_last4': '7890',
  'saved_payment_type': 'gcash',
};

// ─── Mock Order Response ───────────────────────────────────────────────────────
const Map<String, dynamic> kMockOrderResponse = {
  'id': 1001,
  'order_number': 'BNG-20260907-0042',
  'status': 'pending',
  'subtotal':     281.00,
  'delivery_fee':  49.00,
  'total_amount': 330.00,
  'payment_url': null,
};

// ─── Mock Order Detail ─────────────────────────────────────────────────────────
const Map<String, dynamic> kMockOrderDetail = {
  'id': 1001,
  'order_number': 'BNG-20260907-0042',
  'status': 'preparing',
  'payment_method': 'gcash',
  'total_amount': 330.00,
  'notes': 'Extra chili garlic for siomai please!',
  'created_at': '2026-09-07T10:30:00.000Z',
  'updated_at': '2026-09-07T10:35:00.000Z',
  'items': [
    {'menu_item_id':102,'name':'Siomai de Binondo','quantity':2,'unit_price':85.00,'note':'Extra chili garlic'},
    {'menu_item_id':201,'name':'Lomi Binondo','quantity':1,'unit_price':145.00,'note':null},
    {'menu_item_id':401,'name':'Salted Caramel Milk Tea','quantity':1,'unit_price':85.00,'note':null},
  ],
  'delivery': {
    'preference': 'own_delivery',
    'status': 'pending_assignment',
    'rider_name': null,
    'rider_contact': null,
    'lalamove_booking_id': null,
  },
};

// ─── Mock Order List ───────────────────────────────────────────────────────────
const List<Map<String, dynamic>> kMockOrderList = [
  {'id':1001,'order_number':'BNG-20260907-0042','status':'preparing','total_amount':330.00,'item_count':4,'payment_method':'gcash','created_at':'2026-09-07T10:30:00.000Z'},
  {'id':998,'order_number':'BNG-20260905-0039','status':'completed','total_amount':245.00,'item_count':3,'payment_method':'cod','created_at':'2026-09-05T12:15:00.000Z'},
  {'id':991,'order_number':'BNG-20260901-0031','status':'completed','total_amount':490.00,'item_count':6,'payment_method':'gcash','created_at':'2026-09-01T18:45:00.000Z'},
  {'id':985,'order_number':'BNG-20260828-0025','status':'cancelled','total_amount':155.00,'item_count':1,'payment_method':'cod','created_at':'2026-08-28T09:00:00.000Z'},
];

// ─── Mock Support Chat ─────────────────────────────────────────────────────────
const Map<String, dynamic> kMockSupportChat = {
  'id': 1,
  'status': 'unlocked',
  'active_order_id': 1001,
  'messages': [
    {'id':1,'content':'Hi! Just want to ask — is my order already being prepared?','sender_type':'customer','related_order_id':1001,'sent_at':'2026-09-07T10:31:00.000Z','is_read':true},
    {'id':2,'content':'Hi Juan! Yes, your order is already being prepared. Estimated 15–20 minutes.','sender_type':'staff','related_order_id':1001,'sent_at':'2026-09-07T10:33:00.000Z','is_read':true},
    {'id':3,'content':'Thank you! Can I add extra sauce?','sender_type':'customer','related_order_id':1001,'sent_at':'2026-09-07T10:34:00.000Z','is_read':true},
  ],
};

// ─── §1.8 Mock Notifications ───────────────────────────────────────────────────
const List<Map<String, dynamic>> kMockNotifications = [
  {
    'id': 1,
    'type': 'order_preparing',
    'message': 'Your order BNG-20260907-0042 is now being prepared by our kitchen.',
    'is_read': false,
    'related_order_id': 1001,
    'related_order_number': 'BNG-20260907-0042',
    'created_at': '2026-09-07T10:35:00.000Z',
  },
  {
    'id': 2,
    'type': 'payment_received',
    'message': 'Payment of ₱330.00 via GCash has been received for order BNG-20260907-0042.',
    'is_read': false,
    'related_order_id': 1001,
    'related_order_number': 'BNG-20260907-0042',
    'created_at': '2026-09-07T10:32:00.000Z',
  },
  {
    'id': 3,
    'type': 'order_confirmed',
    'message': 'Order BNG-20260907-0042 has been confirmed. We\'re on it!',
    'is_read': false,
    'related_order_id': 1001,
    'related_order_number': 'BNG-20260907-0042',
    'created_at': '2026-09-07T10:31:00.000Z',
  },
  {
    'id': 4,
    'type': 'support_message',
    'message': 'Staff replied: "Hi Juan! Yes, your order is already being prepared."',
    'is_read': true,
    'related_order_id': 1001,
    'related_order_number': 'BNG-20260907-0042',
    'created_at': '2026-09-07T10:33:00.000Z',
  },
  {
    'id': 5,
    'type': 'order_completed',
    'message': 'Order BNG-20260905-0039 has been delivered. Enjoy your meal!',
    'is_read': true,
    'related_order_id': 998,
    'related_order_number': 'BNG-20260905-0039',
    'created_at': '2026-09-05T13:10:00.000Z',
  },
  {
    'id': 6,
    'type': 'order_out_for_delivery',
    'message': 'Your rider is on the way for order BNG-20260905-0039!',
    'is_read': true,
    'related_order_id': 998,
    'related_order_number': 'BNG-20260905-0039',
    'created_at': '2026-09-05T12:55:00.000Z',
  },
];

// ─── Mock Menu Data ────────────────────────────────────────────────────────────
const Map<String, dynamic> kMockMenuData = {
  'categories': [
    {'id':1,'name':'Dimsum','description':'Steamed & fried','sort_order':1},
    {'id':2,'name':'Noodles','description':'Hot soups & pancit','sort_order':2},
    {'id':3,'name':'Rice Meals','description':'Silog & ulam','sort_order':3},
    {'id':4,'name':'Drinks','description':'Hot & cold','sort_order':4},
    {'id':5,'name':'Merienda','description':'Light bites','sort_order':5},
  ],
  'items': [
    {'id':101,'category_id':1,'name':'Hakaw (Shrimp Dumpling)','description':'Classic steamed shrimp dumpling.','price':95.00,'photo_url':null,'is_available':true},
    {'id':102,'category_id':1,'name':'Siomai de Binondo','description':'Pork & shrimp siomai. Served with chili garlic oil.','price':85.00,'photo_url':null,'is_available':true,'variants':[{'id':5,'menu_item_id':102,'name':'4 pcs','price':85.00,'is_available':true,'display_order':1,'variant_group_id':2},{'id':6,'menu_item_id':102,'name':'8 pcs','price':155.00,'is_available':true,'display_order':2,'variant_group_id':2}]},
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
    {'id':401,'category_id':4,'name':'Salted Caramel Milk Tea','description':'HK-style milk tea with salted caramel and pearls.','price':85.00,'photo_url':null,'is_available':true,'variants':[{'id':1,'menu_item_id':401,'name':'Hot','price':85.00,'is_available':true,'display_order':1,'variant_group_id':1},{'id':2,'menu_item_id':401,'name':'Cold','price':85.00,'is_available':true,'display_order':2,'variant_group_id':1}]},
    {'id':402,'category_id':4,'name':"Sago't Gulaman",'description':'Classic iced drink with sago, jelly, and arnibal.','price':55.00,'photo_url':null,'is_available':true},
    {'id':403,'category_id':4,'name':'Wintermelon Milk Tea','description':'Smooth wintermelon tea with milk foam.','price':90.00,'photo_url':null,'is_available':true,'variants':[{'id':3,'menu_item_id':403,'name':'Hot','price':90.00,'is_available':true,'display_order':1,'variant_group_id':1},{'id':4,'menu_item_id':403,'name':'Cold','price':90.00,'is_available':true,'display_order':2,'variant_group_id':1}]},
    {'id':404,'category_id':4,'name':'Hot Ginger Tea','description':'Warming fresh-grated ginger tea.','price':45.00,'photo_url':null,'is_available':true},
    {'id':501,'category_id':5,'name':'Egg Tart (Dan Tat)','description':'Flaky pastry with silky egg custard. 2 pcs.','price':65.00,'photo_url':null,'is_available':true},
    {'id':502,'category_id':5,'name':'Sesame Balls (Buchi)','description':'Glutinous rice balls with red bean filling.','price':70.00,'photo_url':null,'is_available':true},
    {'id':503,'category_id':5,'name':'Pineapple Cake','description':'Buttery pastry filled with pineapple jam.','price':55.00,'photo_url':null,'is_available':false},
  ],
};

// ─── Mock Chatbot Replies ──────────────────────────────────────────────────────
final List<Map<String, dynamic>> kMockBotReplies = [
  {'keywords':['available','open','may'],'reply':"Nandito kami at bukas ngayon! Most items are available."},
  {'keywords':['vegetarian','vegan','gulay'],'reply':"Veggie options: Turnip Cake, Sago't Gulaman, Hot Ginger Tea, Egg Tart."},
  {'keywords':['bestseller','popular','recommend'],'reply':"Bestsellers: Siomai de Binondo (₱85), Lomi Binondo (₱145), Yang Chow Fried Rice (₱165)."},
  {'keywords':['delivery','padala','fee'],'reply':"Delivery fees shown at checkout. Metro Manila only. Minimum ₱300."},
  {'keywords':['close','bukas','oras','time','hours'],'reply':"Open daily 7:00 AM – 9:00 PM. Last order 8:30 PM."},
  {'keywords':['price','magkano','how much'],'reply':"Prices range ₱45 – ₱185."},
  {'keywords':['siomai','hakaw','dimsum'],'reply':"Siomai de Binondo ₱85, Hakaw ₱95 — both available!"},
  {'keywords':['lomi','noodle','mami','pancit'],'reply':"Lomi Binondo ₱145, Pancit Canton Special ₱160, La Paz Batchoy ₱155 — all available!"},
  {'keywords':['milk tea','tea','drink'],'reply':"Salted Caramel Milk Tea ₱85, Wintermelon ₱90, Sago't Gulaman ₱55, Hot Ginger Tea ₱45."},
];

String getMockBotReply(String message) {
  final lower = message.toLowerCase();
  for (final entry in kMockBotReplies) {
    final keywords = entry['keywords'] as List<String>;
    if (keywords.any((k) => lower.contains(k))) return entry['reply'] as String;
  }
  return "Hmm, try asking about our menu, bestsellers, hours, or delivery!";
}

// ─── Mock Staff Reply ──────────────────────────────────────────────────────────
String kMockStaffReply(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('ready') || lower.contains('tapos')) {
    return 'Your order is still being prepared. We\'ll notify you once it\'s ready!';
  }
  if (lower.contains('cancel')) {
    return 'We\'ll check on that for you. Note that once preparing, cancellation may not be possible.';
  }
  if (lower.contains('rider') || lower.contains('deliver')) {
    return 'A rider will be assigned once your food is ready. Details coming soon!';
  }
  return 'Thanks for reaching out! We\'ll attend to your concern shortly.';
}

// ─── §Reviews: Mock Data ──────────────────────────────────────────────────────
// Pool of sample reviews. `kMockReviewsForItem` returns a stable, varied slice
// per item so the detail sheet looks realistic while the backend is pending.
const List<Map<String, dynamic>> kMockReviewPool = [
  {
    'id': 1,
    'author_name': 'Mariel S.',
    'rating': 5.0,
    'comment': 'Sobrang sarap! Authentic ang lasa, parang nasa Binondo talaga. '
        'Bababalik-balikan ko ito.',
    'created_at': '2026-09-28T09:12:00.000Z',
  },
  {
    'id': 2,
    'author_name': 'Jonas R.',
    'rating': 4.0,
    'comment': 'Great value for the portion. Medyo matagal lang ang waiting '
        'time noong peak hour.',
    'created_at': '2026-09-24T14:05:00.000Z',
  },
  {
    'id': 3,
    'author_name': 'Alyssa T.',
    'rating': 5.0,
    'comment': 'Perfectly seasoned and served hot. Recommended!',
    'created_at': '2026-09-19T18:40:00.000Z',
  },
  {
    'id': 4,
    'author_name': 'Marco D.',
    'rating': 3.0,
    'comment': 'Okay naman, pero sana mas malaki ang serving para sa price.',
    'created_at': '2026-09-15T11:22:00.000Z',
  },
  {
    'id': 5,
    'author_name': 'Katrina L.',
    'rating': 5.0,
    'comment': 'Favourite ko na! Consistent ang quality every order.',
    'created_at': '2026-09-10T20:15:00.000Z',
  },
  {
    'id': 6,
    'author_name': 'Paolo M.',
    'rating': 4.0,
    'comment': 'Solid comfort food. Presentation is neat and appetising.',
    'created_at': '2026-09-04T12:30:00.000Z',
  },
  {
    'id': 7,
    'author_name': 'Bea C.',
    'rating': 4.0,
    'comment': 'Masarap at bagong luto. Ang packaging ay maayos din.',
    'created_at': '2026-08-30T16:48:00.000Z',
  },
];

List<Map<String, dynamic>> kMockReviewsForItem(int itemId) {
  final pool = kMockReviewPool;
  // Deterministic slice: 2..5 reviews, starting at a stable offset per item.
  final count = 2 + (itemId.abs() % 4);
  final start = itemId.abs() % pool.length;
  return List.generate(count, (i) => pool[(start + i) % pool.length]);
}