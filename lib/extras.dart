import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

// ---------- Saved data (phone / browser mein) ----------

class Profile {
  String name = '';
  String phone = '';
  String address = '';
  String pin = '';
}

final Profile profile = Profile();
final ValueNotifier<List<int>> recent = ValueNotifier<List<int>>([]);
final ValueNotifier<String> pickedColor = ValueNotifier<String>('Black');

SharedPreferences? _prefs;
bool _loading = true;

Product? _byId(int id) {
  for (final p in products) {
    if (p.id == id) return p;
  }
  return null;
}

Future<void> loadSaved() async {
  try {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    darkMode.value = p.getBool('dark') ?? false;
    profile.name = p.getString('p_name') ?? '';
    profile.phone = p.getString('p_phone') ?? '';
    profile.address = p.getString('p_addr') ?? '';
    profile.pin = p.getString('p_pin') ?? '';
    for (final w in p.getStringList('wish') ?? <String>[]) {
      store.wish.add(int.parse(w));
    }
    for (final c in jsonDecode(p.getString('cart') ?? '[]') as List) {
      final m = c as Map;
      final pr = _byId(m['id'] as int);
      if (pr != null) {
        store.lines.add(CartLine(pr, m['size'] as String, m['qty'] as int));
      }
    }
    for (final o in jsonDecode(p.getString('orders') ?? '[]') as List) {
      final m = o as Map;
      final order = Order(
        m['id'] as String,
        List<String>.from(m['items'] as List),
        m['total'] as int,
      );
      order.time = DateTime.fromMillisecondsSinceEpoch(m['t'] as int);
      store.orders.add(order);
    }
    recent.value = (p.getStringList('recent') ?? <String>[])
        .map((e) => int.parse(e))
        .toList();
  } catch (e) {
    // saved data kharab ho to naye se shuru
  }
  _loading = false;
  store.addListener(saveAll);
  darkMode.addListener(saveAll);
  recent.addListener(saveAll);
}

void saveAll() {
  final p = _prefs;
  if (p == null || _loading) return;
  p.setBool('dark', darkMode.value);
  p.setString('p_name', profile.name);
  p.setString('p_phone', profile.phone);
  p.setString('p_addr', profile.address);
  p.setString('p_pin', profile.pin);
  p.setStringList('wish', store.wish.map((e) => '$e').toList());
  p.setString(
    'cart',
    jsonEncode(store.lines
        .map((l) => {'id': l.p.id, 'size': l.size, 'qty': l.qty})
        .toList()),
  );
  p.setString(
    'orders',
    jsonEncode(store.orders
        .map((o) => {
              'id': o.id,
              'items': o.items,
              'total': o.total,
              't': o.time.millisecondsSinceEpoch,
            })
        .toList()),
  );
  p.setStringList('recent', recent.value.map((e) => '$e').toList());
}

void rememberAddress(String n, String a, String p) {
  if (n.trim().isNotEmpty) profile.name = n.trim();
  if (a.trim().isNotEmpty) profile.address = a.trim();
  if (p.trim().isNotEmpty) profile.pin = p.trim();
  saveAll();
}

// ---------- Coupons ----------

int couponValue(String? code, int sub) {
  if (code == 'SAVE10') return (sub * 0.10).round();
  if (code == 'FLAT200') return sub >= 1000 ? 200 : 0;
  if (code == 'WELCOME') {
    final v = (sub * 0.15).round();
    return v > 300 ? 300 : v;
  }
  return 0;
}

bool couponOk(String c) =>
    const ['SAVE10', 'FLAT200', 'WELCOME'].contains(c.trim().toUpperCase());

// ---------- Recently viewed ----------

void addRecent(Product p) {
  pickedColor.value = 'Black';
  final l = List<int>.from(recent.value);
  l.remove(p.id);
  l.insert(0, p.id);
  recent.value = l.take(8).toList();
}

class RecentlyViewed extends StatelessWidget {
  const RecentlyViewed({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<int>>(
      valueListenable: recent,
      builder: (context, ids, _) {
        final items = <Product>[];
        for (final id in ids) {
          final p = _byId(id);
          if (p != null) items.add(p);
        }
        if (items.isEmpty) return const SizedBox.shrink();
        return Container(
          color: card(context),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Recently viewed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 150,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final p in items)
                      GestureDetector(
                        onTap: () => openProduct(context, p),
                        child: Container(
                          width: 90,
                          margin: const EdgeInsets.only(right: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(width: double.infinity, child: NetImg(p)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Sale countdown ----------

class SaleTimer extends StatefulWidget {
  const SaleTimer({super.key});

  @override
  State<SaleTimer> createState() => _SaleTimerState();
}

class _SaleTimerState extends State<SaleTimer> {
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day + 1).difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: Colors.red),
          Text(
            '  Deal ends in ${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------- Product page: stock, colour, similar products ----------

const colorOptions = <String, Color>{
  'Black': Color(0xFF222222),
  'Blue': Color(0xFF2874F0),
  'Brown': Color(0xFF8B5E3C),
  'Green': Color(0xFF388E3C),
  'Red': Color(0xFFD32F2F),
};

class ProductExtras extends StatelessWidget {
  final Product p;
  const ProductExtras(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    // Demo stock: asli app mein ye database se aayega
    var n = (p.id * 7) % 11;
    if (n == 0) n = 3;
    final low = n <= 5;
    final similar = products
        .where((x) => x.id != p.id && (x.tag == p.tag || x.group == p.group))
        .take(6)
        .toList();
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          color: card(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(low ? Icons.local_fire_department : Icons.check_circle, color: low ? Colors.red : green, size: 18),
                  Text(
                    low ? '  Only $n left - order soon' : '  In stock',
                    style: TextStyle(color: low ? Colors.red : green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: pickedColor,
                builder: (context, sel, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Colour: $sel', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final e in colorOptions.entries)
                          GestureDetector(
                            onTap: () => pickedColor.value = e.key,
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: e.value,
                                shape: BoxShape.circle,
                                border: Border.all(color: sel == e.key ? blue : Colors.grey, width: sel == e.key ? 3 : 1),
                              ),
                              child: sel == e.key ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (similar.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: card(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Similar products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 190,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final x in similar)
                        GestureDetector(
                          onTap: () => openProduct(context, x),
                          child: Container(
                            width: 110,
                            margin: const EdgeInsets.only(right: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(width: double.infinity, child: NetImg(x)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(x.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text('₹${x.price}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------- Profile ----------

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final name = TextEditingController(text: profile.name);
  final phone = TextEditingController(text: profile.phone);
  final addr = TextEditingController(text: profile.address);
  final pin = TextEditingController(text: profile.pin);

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    addr.dispose();
    pin.dispose();
    super.dispose();
  }

  void info(String title, String text) {
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: blueBar('My Profile'),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Container(
            color: card(context),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SAVED ADDRESS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                TextField(controller: addr, decoration: const InputDecoration(labelText: 'Address')),
                TextField(controller: pin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pincode')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    profile.name = name.text.trim();
                    profile.phone = phone.text.trim();
                    profile.address = addr.text.trim();
                    profile.pin = pin.text.trim();
                    saveAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address save ho gaya'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: const Text('SAVE'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: darkMode,
            builder: (context, dark, _) => Container(
              color: card(context),
              child: SwitchListTile(
                title: const Text('Dark mode'),
                value: dark,
                onChanged: (v) => darkMode.value = v,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: card(context),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About us'),
                  onTap: () => info('About Style Shop', 'Style Shop ek demo shopping app hai jo Flutter mein banayi gayi hai.'),
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Contact us'),
                  onTap: () => info('Contact us', 'Email: support@styleshop.example\nPhone: +91 00000 00000\n(Ye demo details hain, apni asli details yahan likho.)'),
                ),
                ListTile(
                  leading: const Icon(Icons.replay),
                  title: const Text('Return policy'),
                  onTap: () => info('Return policy', 'Delivery ke 7 din ke andar product wapas kar sakte ho. Product use na hua ho aur tag laga ho.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
