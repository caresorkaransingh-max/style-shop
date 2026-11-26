import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart';

// ---------- Saved Profile & Helpers ----------

class UserProfile {
  String name;
  String address;
  String pin;

  UserProfile({
    this.name = '',
    this.address = '',
    this.pin = '',
  });
}

final UserProfile profile = UserProfile();
final List<Product> recentlyViewed = [];

Future<void> loadSaved() async {}

void rememberAddress(String name, String address, String pin) {
  profile.name = name.trim();
  profile.address = address.trim();
  profile.pin = pin.trim();
}

void addRecent(Product p) {
  recentlyViewed.removeWhere((item) => item.id == p.id);
  recentlyViewed.insert(0, p);
  if (recentlyViewed.length > 8) {
    recentlyViewed.removeLast();
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

// ---------- Login Popup ----------

Future<void> openLoginPopup(BuildContext context) async {
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  bool useEmail = false;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final canContinue = useEmail
            ? emailCtrl.text.trim().contains('@')
            : phoneCtrl.text.trim().length >= 10;

        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, minHeight: 380),
            child: Row(
              children: [
                Container(
                  width: 230,
                  color: blue,
                  padding: const EdgeInsets.all(24),
                  child: const Column(
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
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Log in for the best experience',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setS(() => useEmail = !useEmail),
                            child: Text(
                              useEmail ? 'Use Phone Number' : 'Use Email-ID',
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'By continuing, you agree to Style Shop Terms of Use and Privacy Policy.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: canContinue
                                  ? orange
                                  : Colors.grey.shade300,
                              foregroundColor: canContinue
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                            onPressed: canContinue
                                ? () {
                                    final val = useEmail
                                        ? emailCtrl.text.trim()
                                        : '+91 ${phoneCtrl.text.trim()}';
                                    rememberAddress(
                                      profile.name.isEmpty ? val : profile.name,
                                      profile.address,
                                      profile.pin,
                                    );
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Logged in as $val'),
                                      ),
                                    );
                                  }
                                : null,
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
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
}

// ---------- Support Chat ----------

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

  void _send() {
    final txt = msgCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      messages.add((true, txt));
      messages.add((
        false,
        'Humne aapka message ("$txt") note kar liya hai. Hamari support team jald hi response degi.',
      ));
    });
    msgCtrl.clear();
  }

  @override
  void dispose() {
    msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: blueBar('Support Chat'),
      body: Column(
        children: [
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
                    onPressed: _send,
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
          if (showChatButton)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => openSupportChat(context),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Start Support Chat'),
              ),
            ),
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

// ---------- Profile Page ----------

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController nameCtrl;
  late final TextEditingController addrCtrl;
  late final TextEditingController pinCtrl;

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
    super.dispose();
  }

  void _saveProfile() {
    rememberAddress(nameCtrl.text, addrCtrl.text, pinCtrl.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile & delivery address saved!')),
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
                    const Text(
                      'Delivery Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => openLoginPopup(context),
                      child: const Text('LOGIN / SWITCH'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
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
                onChanged: (v) => darkMode.value = v,
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