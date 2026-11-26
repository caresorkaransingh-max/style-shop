import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'main.dart';

// ---------- Saved Profile, Address Book & Storage ----------

class SavedAddress {
  final String label;
  final String name;
  final String address;
  final String pin;

  const SavedAddress({
    required this.label,
    required this.name,
    required this.address,
    required this.pin,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'name': name,
        'address': address,
        'pin': pin,
      };

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        label: (j['label'] ?? 'Home').toString(),
        name: (j['name'] ?? '').toString(),
        address: (j['address'] ?? '').toString(),
        pin: (j['pin'] ?? '').toString(),
      );
}

class UserProfile {
  String name;
  String address;
  String pin;
  String? loggedInUser;
  List<SavedAddress> addresses;

  UserProfile({
    this.name = '',
    this.address = '',
    this.pin = '',
    this.loggedInUser,
    List<SavedAddress>? addresses,
  }) : addresses = addresses ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'pin': pin,
        'loggedInUser': loggedInUser,
        'addresses': addresses.map((e) => e.toJson()).toList(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: (j['name'] ?? '').toString(),
        address: (j['address'] ?? '').toString(),
        pin: (j['pin'] ?? '').toString(),
        loggedInUser: j['loggedInUser']?.toString(),
        addresses: ((j['addresses'] as List?) ?? [])
            .map((e) => SavedAddress.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

final UserProfile profile = UserProfile();
final List<Product> recentlyViewed = [];

const String _kStoreKey = 'styleshop_store_v1';
const String _kProfileKey = 'styleshop_profile_v1';
const String _kDarkKey = 'styleshop_dark_v1';

void _writeStorage(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

String? _readStorage(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void saveProfileToStorage() {
  _writeStorage(_kProfileKey, jsonEncode(profile.toJson()));
}

void saveStoreToStorage() {
  _writeStorage(_kStoreKey, jsonEncode(store.toJson()));
}

Future<void> loadSaved() async {
  try {
    final darkRaw = _readStorage(_kDarkKey);
    if (darkRaw == 'true') darkMode.value = true;
    if (darkRaw == 'false') darkMode.value = false;

    final pRaw = _readStorage(_kProfileKey);
    if (pRaw != null && pRaw.isNotEmpty) {
      final decoded = jsonDecode(pRaw) as Map<String, dynamic>;
      final loaded = UserProfile.fromJson(decoded);
      profile.name = loaded.name;
      profile.address = loaded.address;
      profile.pin = loaded.pin;
      profile.loggedInUser = loaded.loggedInUser;
      profile.addresses = loaded.addresses;
    }

    final sRaw = _readStorage(_kStoreKey);
    if (sRaw != null && sRaw.isNotEmpty) {
      store.loadFromJson(jsonDecode(sRaw) as Map<String, dynamic>);
    }
  } catch (_) {}
}

void rememberAddress(String name, String address, String pin, {String label = 'Home'}) {
  final cleanName = name.trim();
  final cleanAddr = address.trim();
  final cleanPin = pin.trim();

  profile.name = cleanName;
  profile.address = cleanAddr;
  profile.pin = cleanPin;

  if (cleanName.isNotEmpty && cleanAddr.isNotEmpty && cleanPin.isNotEmpty) {
    final existingIdx = profile.addresses.indexWhere(
      (a) => a.address == cleanAddr && a.pin == cleanPin,
    );
    final item = SavedAddress(
      label: label.trim().isEmpty ? 'Home' : label.trim(),
      name: cleanName,
      address: cleanAddr,
      pin: cleanPin,
    );
    if (existingIdx >= 0) {
      profile.addresses[existingIdx] = item;
    } else {
      profile.addresses.insert(0, item);
      if (profile.addresses.length > 5) profile.addresses.removeLast();
    }
  }
  saveProfileToStorage();
}

void addRecent(Product p) {
  recentlyViewed.removeWhere((item) => item.id == p.id);
  recentlyViewed.insert(0, p);
  if (recentlyViewed.length > 8) {
    recentlyViewed.removeLast();
  }
}

void shareProductLink(BuildContext context, Product p) {
  final base = html.window.location.href.split('#').first;
  final sep = base.contains('?') ? '&' : '?';
  final link = '${base}${sep}product=${p.id}';
  try {
    html.window.navigator.clipboard?.writeText(link);
  } catch (_) {}
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Link copied: $link')),
  );
}

void openWhatsAppSupport(BuildContext context, {String? customText}) {
  final text = Uri.encodeComponent(
    customText ?? 'Hello Style Shop Support, mujhe order/help chahiye.',
  );
  final url = 'https://wa.me/919999999999?text=$text';
  try {
    html.window.open(url, '_blank');
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp link opened in browser')),
    );
  }
}

// ---------- Coupons ----------

bool couponOk(String? code) {
  if (code == null) return false;
  final c = code.trim().toUpperCase();
  return c == 'SAVE10' || c == 'FLAT200' || c == 'WELCOME';
}

int couponValue(String? code, int subTotal) {
  if (code == null || subTotal <= 0) return 0;
  final c = code.trim().toUpperCase();
  if (c == 'SAVE10') return (subTotal * 0.10).round();
  if (c == 'FLAT200') return subTotal >= 200 ? 200 : subTotal;
  if (c == 'WELCOME') return (subTotal * 0.15).round().clamp(0, 500);
  return 0;
}

// ---------- Size Chart Modal ----------

void showSizeChartDialog(BuildContext context, Product p) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${p.name} — Size Chart'),
      content: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('Size')),
            DataColumn(label: Text('Chest')),
            DataColumn(label: Text('Length')),
          ],
          rows: const [
            DataRow(cells: [DataCell(Text('S')), DataCell(Text('38 in')), DataCell(Text('26 in'))]),
            DataRow(cells: [DataCell(Text('M')), DataCell(Text('40 in')), DataCell(Text('27 in'))]),
            DataRow(cells: [DataCell(Text('L')), DataCell(Text('42 in')), DataCell(Text('28 in'))]),
            DataRow(cells: [DataCell(Text('XL')), DataCell(Text('44 in')), DataCell(Text('29 in'))]),
            DataRow(cells: [DataCell(Text('XXL')), DataCell(Text('46 in')), DataCell(Text('30 in'))]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('CLOSE'),
        ),
      ],
    ),
  );
}

// ---------- Sale Timer & Recently Viewed ----------

class SaleTimer extends StatefulWidget {
  const SaleTimer({super.key});

  @override
  State<SaleTimer> createState() => _SaleTimerState();
}

class _SaleTimerState extends State<SaleTimer> {
  Duration left = const Duration(hours: 3, minutes: 45, seconds: 30);
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (left.inSeconds > 0) {
          left -= const Duration(seconds: 1);
        }
      });
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = _two(left.inHours);
    final m = _two(left.inMinutes.remainder(60));
    final s = _two(left.inSeconds.remainder(60));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: orange, size: 18),
          const SizedBox(width: 4),
          Text(
            'Ends in $h:$m:$s',
            style: const TextStyle(
              color: orange,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class RecentlyViewed extends StatelessWidget {
  const RecentlyViewed({super.key});

  @override
  Widget build(BuildContext context) {
    if (recentlyViewed.isEmpty) return const SizedBox.shrink();
    return Container(
      color: card(context),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Recently Viewed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 175,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final p in recentlyViewed)
                  GestureDetector(
                    onTap: () => openProduct(context, p),
                    child: Container(
                      width: 115,
                      margin: const EdgeInsets.only(right: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: double.infinity,
                                child: NetImg(p),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '₹${p.price}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
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
  }
}

// ---------- Responsive Login Popup with 4-Digit OTP ----------

Future<void> openLoginPopup(BuildContext context) async {
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  bool useEmail = false;
  bool otpSent = false;
  int resendSec = 30;
  Timer? countdown;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        void startResendTimer() {
          countdown?.cancel();
          resendSec = 30;
          countdown = Timer.periodic(const Duration(seconds: 1), (tm) {
            if (resendSec <= 1) {
              tm.cancel();
              setS(() => resendSec = 0);
            } else {
              setS(() => resendSec--);
            }
          });
        }

        final isMobile = MediaQuery.of(ctx).size.width < 600;
        final contactValid = useEmail
            ? emailCtrl.text.trim().contains('@')
            : phoneCtrl.text.trim().length >= 10;
        final otpValid = otpCtrl.text.trim().length == 4;

        final blueSide = Container(
          width: isMobile ? double.infinity : 230,
          color: blue,
          padding: EdgeInsets.all(isMobile ? 18 : 24),
          child: isMobile
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Get access to your Orders, Wishlist and Recommendations',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                )
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Get access to your Orders, Wishlist and Recommendations',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    Spacer(),
                    Icon(
                      Icons.shopping_bag_rounded,
                      color: Colors.amber,
                      size: 72,
                    ),
                  ],
                ),
        );

        final formSide = Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                otpSent ? 'Verify 4-digit OTP' : 'Log in for the best experience',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              if (!otpSent) ...[
                if (!useEmail)
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setS(() {}),
                    decoration: const InputDecoration(
                      prefixText: '+91  ',
                      labelText: 'Enter Phone Number',
                      border: OutlineInputBorder(),
                    ),
                  )
                else
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setS(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Enter Email ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setS(() => useEmail = !useEmail),
                    child: Text(
                      useEmail ? 'Use Phone Number' : 'Use Email-ID',
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'OTP sent to ${useEmail ? emailCtrl.text.trim() : '+91 ${phoneCtrl.text.trim()}'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: otpCtrl,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setS(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Enter 4-digit OTP (e.g. 1234)',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setS(() {
                        otpSent = false;
                        otpCtrl.clear();
                      }),
                      child: const Text('Change'),
                    ),
                    TextButton(
                      onPressed: resendSec == 0
                          ? () {
                              startResendTimer();
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('OTP resent!')),
                              );
                            }
                          : null,
                      child: Text(
                        resendSec == 0 ? 'Resend OTP' : 'Resend in ${resendSec}s',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              const Text(
                'By continuing, you agree to Style Shop Terms of Use and Privacy Policy.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: (!otpSent ? contactValid : otpValid)
                        ? orange
                        : Colors.grey.shade300,
                    foregroundColor: (!otpSent ? contactValid : otpValid)
                        ? Colors.white
                        : Colors.grey.shade700,
                  ),
                  onPressed: !otpSent
                      ? (contactValid
                          ? () {
                              setS(() => otpSent = true);
                              startResendTimer();
                            }
                          : null)
                      : (otpValid
                          ? () {
                              countdown?.cancel();
                              final val = useEmail
                                  ? emailCtrl.text.trim()
                                  : '+91 ${phoneCtrl.text.trim()}';
                              profile.loggedInUser = val;
                              rememberAddress(
                                profile.name.isEmpty ? val : profile.name,
                                profile.address,
                                profile.pin,
                              );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Verified & logged in as $val')),
                              );
                            }
                          : null),
                  child: Text(!otpSent ? 'Continue' : 'Verify OTP'),
                ),
              ),
            ],
          ),
        );

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: Theme.of(ctx).colorScheme.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isMobile
                      ? SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [blueSide, formSide],
                          ),
                        )
                      : IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              blueSide,
                              Expanded(child: formSide),
                            ],
                          ),
                        ),
                ),
                Positioned(
                  top: -14,
                  right: -14,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        countdown?.cancel();
                        Navigator.pop(ctx);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  countdown?.cancel();
}

// ---------- Smart Support Chat ----------

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final TextEditingController msgCtrl = TextEditingController();
  final List<(bool isUser, String text)> messages = [
    (
      false,
      'Namaste! Style Shop Support mein aapka swagat hai. Order, payment ya return mein kya madad chahiye?',
    ),
  ];

  String _autoReply(String txt) {
    final l = txt.toLowerCase();
    if (l.contains('order') || l.contains('track')) {
      return 'Aap apne order ka live status Orders tab -> TRACK ORDER par dekh sakte hain.';
    }
    if (l.contains('return') || l.contains('refund')) {
      return 'Delivery ke 7 din ke andar Orders tab se Return Request submit ki ja sakti hai.';
    }
    if (l.contains('pay') || l.contains('upi') || l.contains('card')) {
      return 'Agar UPI/Card payment pending ya cancel ho jaye to order place nahi hota; dobara checkout se try karein.';
    }
    return 'Humne aapka message ("$txt") note kar liya hai. Hamari support team jald hi reply degi.';
  }

  void _send([String? preset]) {
    final txt = (preset ?? msgCtrl.text).trim();
    if (txt.isEmpty) return;
    setState(() {
      messages.add((true, txt));
      messages.add((false, _autoReply(txt)));
    });
    if (preset == null) msgCtrl.clear();
  }

  @override
  void dispose() {
    msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const quickChips = [
      'Where is my order?',
      'Return policy',
      'Payment issue',
    ];
    return Scaffold(
      appBar: blueBar(
        'Support Chat',
        actions: [
          IconButton(
            tooltip: 'WhatsApp Support',
            onPressed: () => openWhatsAppSupport(context),
            icon: const Icon(Icons.call, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: card(context),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final q in quickChips)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(q),
                        onPressed: () => _send(q),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final (isUser, text) = messages[i];
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: const BoxConstraints(maxWidth: 360),
                    decoration: BoxDecoration(
                      color: isUser ? blue : card(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(color: isUser ? Colors.white : null),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: card(context),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: msgCtrl,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Apna message likhein...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: blue),
                    onPressed: () => _send(),
                    child: const Icon(Icons.send, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void openSupportChat(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SupportChatPage()),
  );
}

// ---------- Info Pages (About us, Contact us, Return policy) ----------

class InfoPage extends StatelessWidget {
  final String title;
  final List<(String, String)> sections;
  final bool showChatButton;

  const InfoPage({
    super.key,
    required this.title,
    required this.sections,
    this.showChatButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: blueBar(title),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final sec in sections)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sec.$1,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sec.$2,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          if (showChatButton) ...[
            const SizedBox(height: 4),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => openSupportChat(context),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Start Support Chat'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: green,
                side: const BorderSide(color: green),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => openWhatsAppSupport(context),
              icon: const Icon(Icons.chat),
              label: const Text('Chat on WhatsApp'),
            ),
          ],
        ],
      ),
    );
  }
}

void openAboutUs(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const InfoPage(
        title: 'About Us',
        sections: [
          (
            'Welcome to Style Shop',
            'Style Shop ek modern online shopping store hai jahan aapko fashion, mobiles, electronics aur home essentials best prices aur fast delivery ke saath milte hain.',
          ),
          (
            'Quality & Trust',
            'Har product ko quality aur customer satisfaction ke saath list kiya gaya hai. Transparent pricing, coupon offers aur easy return policy hamari priority hai.',
          ),
        ],
      ),
    ),
  );
}

void openContactUs(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const InfoPage(
        title: 'Contact Us',
        showChatButton: true,
        sections: [
          (
            'Customer Support Email',
            'support@styleshop.example.com — Aap apne order, delivery ya payment se judi kisi bhi query ke liye humein mail kar sakte hain.',
          ),
          (
            'Support Hours',
            'Monday to Saturday, 9:00 AM to 7:00 PM IST.',
          ),
          (
            'Office Address',
            'Style Shop Retail Hub, Sahibzada Ajit Singh Nagar, Punjab, India.',
          ),
        ],
      ),
    ),
  );
}

void openReturnPolicy(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const InfoPage(
        title: 'Return & Refund Policy',
        sections: [
          (
            '7 Days Easy Returns',
            'Delivery ke 7 din ke andar agar product damaged, defective ya size/variant issue ke saath mile to aap return/exchange ke liye request kar sakte hain.',
          ),
          (
            'Eligibility Conditions',
            'Item unused hona chahiye aur original tags, packaging aur accessories ke saath hona zaroori hai.',
          ),
          (
            'Refund Timeline',
            'Return item verify hone ke baad prepaid/UPI/card refund 3–5 working days mein source account mein credit ho jata hai.',
          ),
        ],
      ),
    ),
  );
}

// ---------- Profile Page (with Address Book) ----------

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController nameCtrl;
  late final TextEditingController addrCtrl;
  late final TextEditingController pinCtrl;
  final TextEditingController labelCtrl = TextEditingController(text: 'Home');

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: profile.name);
    addrCtrl = TextEditingController(text: profile.address);
    pinCtrl = TextEditingController(text: profile.pin);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addrCtrl.dispose();
    pinCtrl.dispose();
    labelCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    rememberAddress(
      nameCtrl.text,
      addrCtrl.text,
      pinCtrl.text,
      label: labelCtrl.text,
    );
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile & address saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: blueBar('My Profile'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (profile.loggedInUser != null)
                            Text(
                              'Account: ${profile.loggedInUser}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await openLoginPopup(context);
                        if (mounted) {
                          nameCtrl.text = profile.name;
                          setState(() {});
                        }
                      },
                      child: const Text('LOGIN / SWITCH'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label (Home / Office / Family)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pincode',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _saveProfile,
                  child: const Text('SAVE'),
                ),
              ],
            ),
          ),
          if (profile.addresses.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved Addresses',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final a in profile.addresses)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined, color: blue),
                      title: Text('${a.label} — ${a.name}'),
                      subtitle: Text('${a.address}, ${a.pin}'),
                      trailing: TextButton(
                        onPressed: () {
                          rememberAddress(a.name, a.address, a.pin, label: a.label);
                          nameCtrl.text = a.name;
                          addrCtrl.text = a.address;
                          pinCtrl.text = a.pin;
                          labelCtrl.text = a.label;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${a.label} address selected')),
                          );
                        },
                        child: const Text('USE'),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: card(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: darkMode,
              builder: (context, dark, _) => SwitchListTile(
                title: const Text('Dark mode'),
                value: dark,
                onChanged: (v) {
                  darkMode.value = v;
                  _writeStorage(_kDarkKey, v.toString());
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: card(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text('Support chat'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openSupportChat(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About us'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openAboutUs(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Contact us'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openContactUs(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.assignment_return_outlined),
                  title: const Text('Return policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openReturnPolicy(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}