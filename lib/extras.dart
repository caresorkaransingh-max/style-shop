import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'main.dart';

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
const String _kCustomProductsKey = 'styleshop_custom_products_v1';

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

void saveDarkMode(bool enabled) {
  _writeStorage(_kDarkKey, enabled.toString());
}

void saveProfileToStorage() {
  _writeStorage(_kProfileKey, jsonEncode(profile.toJson()));
}

void saveStoreToStorage() {
  _writeStorage(_kStoreKey, jsonEncode(store.toJson()));
}

void saveCatalogToStorage() {
  try {
    final encoded = jsonEncode(products.map((p) => p.toJson()).toList());
    _writeStorage(_kCustomProductsKey, encoded);
  } catch (_) {}
}

Future<void> loadSaved() async {
  try {
    html.document.title = 'Style Shop';

    final darkRaw = _readStorage(_kDarkKey);
    if (darkRaw == 'true') darkMode.value = true;
    if (darkRaw == 'false') darkMode.value = false;

    final cRaw = _readStorage(_kCustomProductsKey);
    if (cRaw != null && cRaw.isNotEmpty) {
      final decodedList = jsonDecode(cRaw) as List;
      final loadedProducts = decodedList
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (loadedProducts.isNotEmpty) {
        products
          ..clear()
          ..addAll(loadedProducts);
      }
    } else {
      saveCatalogToStorage();
    }

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

// Pick image or video file from device (Web)
Future<String?> pickMediaFileFromDevice({required bool isVideo}) async {
  final completer = Completer<String?>();
  try {
    final input = html.FileUploadInputElement()
      ..accept = isVideo ? 'video/*' : 'image/*';
    input.click();

    input.onChange.listen((_) {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      if (isVideo) {
        final blobUrl = html.Url.createObjectUrlFromBlob(file);
        if (!completer.isCompleted) completer.complete(blobUrl);
        return;
      }

      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        final res = reader.result?.toString();
        if (!completer.isCompleted) {
          completer.complete((res != null && res.isNotEmpty) ? res : null);
        }
      });
      reader.onError.listen((_) {
        if (!completer.isCompleted) completer.complete(null);
      });
      reader.readAsDataUrl(file);
    });

    Future.delayed(const Duration(seconds: 60), () {
      if (!completer.isCompleted) completer.complete(null);
    });
  } catch (_) {
    if (!completer.isCompleted) completer.complete(null);
  }
  return completer.future;
}

bool isVideoMediaUrl(String url) {
  final lower = url.toLowerCase();
  return lower.startsWith('data:video/') ||
      lower.contains('.mp4') ||
      lower.contains('.webm') ||
      lower.contains('.ogg') ||
      lower.contains('.mov') ||
      lower.contains('blob:');
}

// Web Video Preview Widget for Detail Page
class WebVideoPlayer extends StatefulWidget {
  final String url;
  final double height;
  const WebVideoPlayer({super.key, required this.url, this.height = 320});

  @override
  State<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<WebVideoPlayer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'ss-video-${widget.url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    // ignore: undefined_prefixed_name
    html.document.registerElement;
    try {
      // ignore: avoid_dynamic_calls
      final uiWeb = (html.window as dynamic);
      final _ = uiWeb;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
          const SizedBox(height: 10),
          const Text(
            'Product Video Attached',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: blue),
            onPressed: () {
              try {
                html.window.open(widget.url, '_blank');
              } catch (_) {}
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('OPEN VIDEO IN PLAYER'),
          ),
        ],
      ),
    );
  }
}

// Deep-link support (?product=ID)
void handleDeepLinkIfAny(BuildContext context) {
  try {
    final uri = Uri.parse(html.window.location.href);
    final rawId = uri.queryParameters['product'] ?? uri.queryParameters['p'];
    final pid = int.tryParse((rawId ?? '').trim());
    if (pid == null) return;
    final target = products.where((p) => p.id == pid).firstOrNull;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          openProduct(context, target);
        }
      });
    }
  } catch (_) {}
}

void rememberAddress(
  String name,
  String address,
  String pin, {
  String label = 'Home',
}) {
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

String buildProductShareLink(Product p) {
  final base = html.window.location.href.split('?').first.split('#').first;
  final cleanBase = base.endsWith('/') ? base : '$base/';
  return '${cleanBase}?product=${p.id}';
}

void shareProductLink(BuildContext context, Product p) {
  final link = buildProductShareLink(p);
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

// Downloadable / Printable Order Invoice
void downloadOrderInvoice(BuildContext context, Order o) {
  final itemsRows = o.items
      .map(
        (item) =>
            '<tr><td style="padding:8px;border-bottom:1px solid #eee;">$item</td><td style="padding:8px;border-bottom:1px solid #eee;text-align:right;">Included</td></tr>',
      )
      .join();
  final customerName = profile.name.isNotEmpty
      ? profile.name
      : (profile.loggedInUser ?? 'Valued Customer');
  final customerAddr = profile.address.isNotEmpty
      ? '${profile.address} - ${profile.pin}'
      : 'Style Shop Customer Address';

  final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Invoice - ${o.id}</title>
  <style>
    body { font-family: Arial, sans-serif; padding: 28px; color: #222; max-width: 720px; margin: auto; }
    .hdr { display: flex; justify-content: space-between; border-bottom: 2px solid #2874F0; padding-bottom: 12px; margin-bottom: 20px; }
    .brand { font-size: 24px; font-weight: bold; color: #2874F0; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; }
    th { text-align: left; background: #f4f6fa; padding: 10px; border-bottom: 2px solid #ddd; }
    .total { font-size: 18px; font-weight: bold; text-align: right; margin-top: 18px; }
    .btn { margin-top: 24px; padding: 10px 18px; background: #2874F0; color: #fff; border: none; border-radius: 6px; cursor: pointer; }
    @media print { .btn { display: none; } }
  </style>
</head>
<body>
  <div class="hdr">
    <div>
      <div class="brand">Style Shop</div>
      <div>Tax / Order Invoice</div>
    </div>
    <div style="text-align:right;">
      <div><strong>Order ID:</strong> ${o.id}</div>
      <div><strong>Status:</strong> ${o.statusLabel}</div>
      <div><strong>Date:</strong> ${o.time.toString().split('.').first}</div>
    </div>
  </div>
  <div>
    <strong>Billed To:</strong> $customerName<br/>
    <strong>Address:</strong> $customerAddr
  </div>
  <table>
    <thead>
      <tr><th>Item Description</th><th style="text-align:right;">Details</th></tr>
    </thead>
    <tbody>$itemsRows</tbody>
  </table>
  <div class="total">Grand Total: ₹${o.total}</div>
  <button class="btn" onclick="window.print()">Print / Save as PDF</button>
</body>
</html>
''';

  try {
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice opened for ${o.id} (Print / Save PDF)')),
    );
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open invoice window')),
    );
  }
}

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

void showSizeChartDialog(BuildContext context, Product p) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${p.name} - Size Chart'),
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

// Similar Products section on Detail Page
class SimilarProductsSection extends StatelessWidget {
  final Product currentProduct;
  const SimilarProductsSection({super.key, required this.currentProduct});

  @override
  Widget build(BuildContext context) {
    final similar = products
        .where(
          (item) =>
              item.id != currentProduct.id &&
              (item.group == currentProduct.group || item.tag == currentProduct.tag),
        )
        .take(6)
        .toList();

    if (similar.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: card(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Similar Products',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 205,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final p in similar)
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) {
                          addRecent(p);
                          return DetailPage(product: p);
                        }),
                      );
                    },
                    child: Container(
                      width: 135,
                      margin: const EdgeInsets.only(right: 12),
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
                          const SizedBox(height: 6),
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '₹${p.price}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${p.off}% off',
                                style: const TextStyle(
                                  color: green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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

// Admin Panel (Add Products with Color Variants, Upload Image/Video + Remove Products + Manage Orders)
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final nameCtrl = TextEditingController();
  final brandCtrl = TextEditingController(text: 'Style Co');
  final priceCtrl = TextEditingController(text: '1499');
  final mrpCtrl = TextEditingController(text: '2499');
  final stockCtrl = TextEditingController(text: '10');
  final videoUrlCtrl = TextEditingController();

  // Variant 1
  final c1NameCtrl = TextEditingController(text: 'Black');
  final c1ImgCtrl = TextEditingController(text: px(1072036));
  Color c1Color = const Color(0xFF222222);

  // Variant 2
  final c2NameCtrl = TextEditingController(text: 'Brown');
  final c2ImgCtrl = TextEditingController(text: px(15133974));
  Color c2Color = const Color(0xFF8B5E3C);

  // Variant 3
  final c3NameCtrl = TextEditingController(text: 'Blue');
  final c3ImgCtrl = TextEditingController(text: px(991509));
  Color c3Color = const Color(0xFF378ADD);

  String selectedGroup = 'Men';
  String selectedTag = 'T-Shirt';

  static const List<(String, Color)> _colorPresets = [
    ('Black', Color(0xFF222222)),
    ('White', Color(0xFFF5F5F5)),
    ('Brown', Color(0xFF8B5E3C)),
    ('Blue', Color(0xFF378ADD)),
    ('Navy', Color(0xFF1E3A8A)),
    ('Red', Color(0xFFA32D2D)),
    ('Pink', Color(0xFFD4537E)),
    ('Green', Color(0xFF1D9E75)),
    ('Yellow', Color(0xFFEAB308)),
  ];

  @override
  void dispose() {
    nameCtrl.dispose();
    brandCtrl.dispose();
    priceCtrl.dispose();
    mrpCtrl.dispose();
    stockCtrl.dispose();
    videoUrlCtrl.dispose();
    c1NameCtrl.dispose();
    c1ImgCtrl.dispose();
    c2NameCtrl.dispose();
    c2ImgCtrl.dispose();
    c3NameCtrl.dispose();
    c3ImgCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadVariantImage(TextEditingController imgCtrl) async {
    final picked = await pickMediaFileFromDevice(isVideo: false);
    if (!mounted) return;
    if (picked != null) {
      imgCtrl.text = picked;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload ho gayi!')),
      );
    }
  }

  Future<void> _uploadProductVideo() async {
    final picked = await pickMediaFileFromDevice(isVideo: true);
    if (!mounted) return;
    if (picked != null) {
      videoUrlCtrl.text = picked;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video attach ho gayi!')),
      );
    }
  }

  List<ProductVariant> _buildVariants() {
    final list = <ProductVariant>[];
    final entries = [
      (c1NameCtrl.text.trim(), c1ImgCtrl.text.trim(), c1Color),
      (c2NameCtrl.text.trim(), c2ImgCtrl.text.trim(), c2Color),
      (c3NameCtrl.text.trim(), c3ImgCtrl.text.trim(), c3Color),
    ];

    for (final (cName, imgUrl, swatch) in entries) {
      if (cName.isNotEmpty || imgUrl.isNotEmpty) {
        list.add(
          ProductVariant(
            cName.isEmpty ? 'Color ${list.length + 1}' : cName,
            swatch,
            [imgUrl.isEmpty ? px(15133974) : imgUrl],
          ),
        );
      }
    }

    if (list.isEmpty) {
      list.add(ProductVariant('Default', c1Color, [px(15133974)]));
    }
    return list;
  }

  Widget _variantInputCard({
    required String title,
    required TextEditingController colorCtrl,
    required TextEditingController imgCtrl,
    required Color currentSwatch,
    required ValueChanged<Color> onSwatchChange,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 10, backgroundColor: currentSwatch),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: blue,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _uploadVariantImage(imgCtrl),
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('Upload Image'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: colorCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Color Name (e.g. Red)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: imgCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Image URL ya Uploaded Image',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in _colorPresets)
                GestureDetector(
                  onTap: () {
                    colorCtrl.text = preset.$1;
                    onSwatchChange(preset.$2);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: currentSwatch == preset.$2
                            ? blue
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 6, backgroundColor: preset.$2),
                        const SizedBox(width: 4),
                        Text(preset.$1, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _addProduct() {
    final name = nameCtrl.text.trim();
    final brand = brandCtrl.text.trim().isEmpty ? 'Style Co' : brandCtrl.text.trim();
    final price = int.tryParse(priceCtrl.text.trim()) ?? 999;
    final mrp = int.tryParse(mrpCtrl.text.trim()) ?? (price + 500);
    final stock = int.tryParse(stockCtrl.text.trim()) ?? 10;
    final vid = videoUrlCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name likhein')),
      );
      return;
    }

    final builtVariants = _buildVariants();
    final primaryImg = builtVariants.first.images.first;
    final primaryColor = builtVariants.first.swatch;
    final nextId =
        (products.map((e) => e.id).fold(0, (a, b) => a > b ? a : b)) + 1;

    products.insert(
      0,
      Product(
        nextId,
        name,
        brand,
        selectedTag,
        selectedGroup,
        price,
        mrp < price ? price + 400 : mrp,
        4.5,
        120,
        Icons.shopping_bag,
        primaryColor,
        primaryImg,
        stock: stock,
        variants: builtVariants,
        videoUrl: vid.isEmpty ? null : vid,
      ),
    );
    nameCtrl.clear();
    videoUrlCtrl.clear();
    saveCatalogToStorage();
    catalogVersion.value++;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"$name" (${builtVariants.length} variants) store mein add ho gaya!',
        ),
      ),
    );
  }

  void _removeProduct(Product p) {
    products.removeWhere((item) => item.id == p.id);
    recentlyViewed.removeWhere((item) => item.id == p.id);
    store.wish.remove(p.id);
    store.lines.removeWhere((line) => line.p.id == p.id);
    saveCatalogToStorage();
    saveStoreToStorage();
    catalogVersion.value++;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${p.name}" store se remove kar diya gaya')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: blueBar('Admin Panel'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
                  'Add New Product',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: brandCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedGroup,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Men', child: Text('Men')),
                          DropdownMenuItem(value: 'Women', child: Text('Women')),
                          DropdownMenuItem(value: 'Mobiles', child: Text('Mobiles')),
                          DropdownMenuItem(value: 'Electronics', child: Text('Electronics')),
                          DropdownMenuItem(value: 'Home', child: Text('Home')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => selectedGroup = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedTag,
                        decoration: const InputDecoration(
                          labelText: 'Type Tag',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'T-Shirt', child: Text('T-Shirt')),
                          DropdownMenuItem(value: 'Jacket', child: Text('Jacket')),
                          DropdownMenuItem(value: 'Dress', child: Text('Dress')),
                          DropdownMenuItem(value: 'Pant', child: Text('Pant')),
                          DropdownMenuItem(value: 'Mobile', child: Text('Mobile')),
                          DropdownMenuItem(value: 'Headphone', child: Text('Headphone')),
                          DropdownMenuItem(value: 'Laptop', child: Text('Laptop')),
                          DropdownMenuItem(value: 'Decor', child: Text('Decor')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => selectedTag = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sale Price (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: mrpCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'MRP (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Color Variants, Images & Video',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Har color ke liye image URL daalein ya "Upload Image" se file chunein. Neeche product video bhi upload/link kar sakte hain.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _variantInputCard(
                  title: 'Color Variant 1 (Main)',
                  colorCtrl: c1NameCtrl,
                  imgCtrl: c1ImgCtrl,
                  currentSwatch: c1Color,
                  onSwatchChange: (col) => c1Color = col,
                ),
                _variantInputCard(
                  title: 'Color Variant 2',
                  colorCtrl: c2NameCtrl,
                  imgCtrl: c2ImgCtrl,
                  currentSwatch: c2Color,
                  onSwatchChange: (col) => c2Color = col,
                ),
                _variantInputCard(
                  title: 'Color Variant 3',
                  colorCtrl: c3NameCtrl,
                  imgCtrl: c3ImgCtrl,
                  currentSwatch: c3Color,
                  onSwatchChange: (col) => c3Color = col,
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.videocam_outlined, color: blue, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Product Video (Optional)',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: blue,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: _uploadProductVideo,
                            icon: const Icon(Icons.video_call, size: 18),
                            label: const Text('Upload Video'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: videoUrlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Video URL (.mp4) ya Uploaded Video',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _addProduct,
                    icon: const Icon(Icons.add),
                    label: const Text('ADD PRODUCT TO STORE'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: card(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store Products (${products.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Agar koi product galat add ho gaya ho ya hatana ho to Remove dabayein.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                if (products.isEmpty)
                  const Text(
                    'Store mein koi product nahi hai',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  for (final p in List<Product>.from(products))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: NetImg(p),
                        ),
                      ),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${p.brand} • ${p.group} • ₹${p.price}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _removeProduct(p),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove'),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Orders (${store.orders.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (store.orders.isEmpty)
                    const Text(
                      'Abhi koi order nahi hai',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    for (final o in store.orders)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${o.id} — ₹${o.total}'),
                        subtitle: Text('Current Status: ${o.statusLabel}'),
                        trailing: DropdownButton<String>(
                          value: [
                            'Placed',
                            'Shipped',
                            'Out for delivery',
                            'Delivered',
                            'Cancelled',
                          ].contains(o.statusLabel)
                              ? o.statusLabel
                              : 'Placed',
                          items: const [
                            DropdownMenuItem(value: 'Placed', child: Text('Placed')),
                            DropdownMenuItem(value: 'Shipped', child: Text('Shipped')),
                            DropdownMenuItem(
                              value: 'Out for delivery',
                              child: Text('Out for delivery'),
                            ),
                            DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
                            DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                          ],
                          onChanged: (newStatus) {
                            if (newStatus != null) {
                              store.setOrderStatus(o.id, newStatus);
                            }
                          },
                        ),
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

void openAdminPanel(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminPanelPage()),
  );
}

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
                  'Demo OTP sent to ${useEmail ? emailCtrl.text.trim() : '+91 ${phoneCtrl.text.trim()}'} (Test code: 1234)',
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
                                const SnackBar(
                                  content: Text('OTP resent! (Demo: 1234)'),
                                ),
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
                                SnackBar(
                                  content: Text('Verified & logged in as $val'),
                                ),
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
            'support@styleshop.example.com - Aap apne order, delivery ya payment se judi kisi bhi query ke liye humein mail kar sakte hain.',
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
            'Return item verify hone ke baad prepaid/UPI/card refund 3-5 working days mein source account mein credit ho jata hai.',
          ),
        ],
      ),
    ),
  );
}

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
                      title: Text('${a.label} - ${a.name}'),
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
                  saveDarkMode(v);
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
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: blue,
                  ),
                  title: const Text('Admin Panel'),
                  subtitle: const Text('Add products & manage order status'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openAdminPanel(context),
                ),
                const Divider(height: 1),
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

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String pay = 'UPI';
  bool _processingPay = false;
  late final TextEditingController name;
  late final TextEditingController addr;
  late final TextEditingController pin;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: profile.name);
    addr = TextEditingController(text: profile.address);
    pin = TextEditingController(text: profile.pin);
  }

  @override
  void dispose() {
    name.dispose();
    addr.dispose();
    pin.dispose();
    super.dispose();
  }

  Future<void> _handlePay() async {
    if (store.lines.isEmpty || _processingPay) return;

    if (name.text.trim().isEmpty ||
        addr.text.trim().isEmpty ||
        pin.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill name, address and pincode')),
      );
      return;
    }

    if (pay == 'UPI' || pay == 'Credit / Debit card') {
      final paid = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: Text('$pay - Gateway Checkout'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount to pay: ₹${store.total}'),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    labelText: pay == 'UPI'
                        ? 'Enter UPI ID (e.g. name@upi)'
                        : 'Enter last 4 digits of card',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Payment complete hone ke baad hi order place hoga.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CANCEL PAYMENT'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: green),
                onPressed: () {
                  if (ctrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter details to pay'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('COMPLETE PAYMENT'),
              ),
            ],
          );
        },
      );

      if (paid != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment not completed. Order not placed.'),
          ),
        );
        return;
      }
    } else {
      final confirmCod = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Cash on Delivery'),
          content: Text(
            'Delivery ke waqt ₹${store.total} cash dena hoga. Order confirm karein?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('NO'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: orange),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('CONFIRM ORDER'),
            ),
          ],
        ),
      );
      if (confirmCod != true) return;
    }

    setState(() => _processingPay = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    rememberAddress(name.text, addr.text, pin.text);
    final id = store.placeOrder();
    setState(() => _processingPay = false);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => SuccessPage(orderId: id, pay: pay)),
      (r) => r.isFirst,
    );
  }

  Widget box(List<Widget> children) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        color: card(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final saved = store.mrpTotal - store.total;
        return Scaffold(
          appBar: blueBar('Checkout'),
          body: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              box([
                const Text(
                  'DELIVERY ADDRESS',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (profile.addresses.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final a in profile.addresses)
                        ActionChip(
                          avatar: const Icon(Icons.location_on, size: 16),
                          label: Text('${a.label} (${a.pin})'),
                          onPressed: () {
                            name.text = a.name;
                            addr.text = a.address;
                            pin.text = a.pin;
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                TextField(
                  controller: addr,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: pin,
                  decoration: const InputDecoration(labelText: 'Pincode'),
                ),
              ]),
              box([
                const Text(
                  'PAYMENT METHOD',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                for (final m in [
                  'UPI',
                  'Credit / Debit card',
                  'Cash on delivery',
                ])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      pay == m
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: pay == m ? blue : Colors.grey,
                    ),
                    title: Text(m),
                    onTap: () => setState(() => pay = m),
                  ),
              ]),
              const CouponBox(),
              box([
                const Text(
                  'ORDER SUMMARY',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                priceRow('Price (${store.count} items)', '₹${store.mrpTotal}'),
                priceRow(
                  'Discount',
                  '- ₹${store.mrpTotal - store.subTotal}',
                  color: green,
                ),
                if (store.couponOff > 0)
                  priceRow(
                    'Coupon (${store.coupon})',
                    '- ₹${store.couponOff}',
                    color: green,
                  ),
                priceRow('Delivery charges', 'FREE', color: green),
                const Divider(),
                priceRow('Total payable', '₹${store.total}', bold: true),
                if (store.lines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'You will save ₹$saved on this order',
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ]),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: SizedBox(
              height: 56,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(),
                ),
                onPressed: store.lines.isEmpty || _processingPay
                    ? null
                    : _handlePay,
                child: Text(
                  _processingPay ? 'PROCESSING...' : 'PAY ₹${store.total}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}