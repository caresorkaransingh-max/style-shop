import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const ShopApp());
}

const Color blue = Color(0xFF2874F0);
const Color orange = Color(0xFFFB641B);
const Color green = Color(0xFF388E3C);
const Color bg = Color(0xFFF1F3F6);

String px(int id) =>
    'https://images.pexels.com/photos/$id/pexels-photo-$id.jpeg?auto=compress&cs=tinysrgb&w=500';

// ---------- Theme helpers ----------

final ValueNotifier<bool> darkMode = ValueNotifier<bool>(false);

// Surface color: white in light mode, dark grey in dark mode
Color card(BuildContext c) => Theme.of(c).colorScheme.surface;

// ---------- Live location ----------

final ValueNotifier<String> deliverTo = ValueNotifier<String>(
  'Detecting location...',
);

Future<void> updateLocation() async {
  try {
    deliverTo.value = 'Detecting location...';
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      deliverTo.value = 'Allow location access';
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${pos.latitude}&lon=${pos.longitude}',
    );
    final res = await http.get(uri);
    final data = jsonDecode(res.body) as Map;
    final a = (data['address'] ?? {}) as Map;
    final place =
        a['city'] ??
        a['town'] ??
        a['village'] ??
        a['suburb'] ??
        a['state_district'] ??
        'your area';
    final pin = a['postcode'] ?? '';
    deliverTo.value = 'Deliver to $place $pin'.trim();
  } catch (e) {
    deliverTo.value = 'Tap to set location';
  }
}

// ---------- Data ----------

class Product {
  final int id;
  final String name;
  final String brand;
  final String tag;
  final String group;
  final int price;
  final int mrp;
  final double rating;
  final int reviews;
  final IconData icon;
  final Color color;
  final String img;

  const Product(
    this.id,
    this.name,
    this.brand,
    this.tag,
    this.group,
    this.price,
    this.mrp,
    this.rating,
    this.reviews,
    this.icon,
    this.color,
    this.img,
  );

  int get off => ((mrp - price) * 100 / mrp).round();

  // Size sirf kapdon ke liye
  bool get isCloth => group == 'Men' || group == 'Women';

  // Photo slider ke liye saari photos
  List<String> get gallery => galleryExtra[id] ?? [img];
}

// Har product ki extra photos yahan daalo  ->  id: [photo1, photo2, ...]
final Map<int, List<String>> galleryExtra = {
  1: [px(15133974), px(15133972), px(756484)],
  2: [px(756484), px(1072036)],
  3: [px(4380970), px(15133972)],
  7: [px(1072036), px(756484)],
};

final List<Product> products = [
  Product(
    1,
    'Light Brown Jacket',
    'Style Co',
    'Jacket',
    'Women',
    3499,
    5999,
    4.5,
    2341,
    Icons.checkroom,
    Color(0xFF8B5E3C),
    px(15133974),
  ),
  Product(
    2,
    'Checked Blazer',
    'Urban Wear',
    'Jacket',
    'Men',
    4999,
    8999,
    4.7,
    1876,
    Icons.checkroom,
    Color(0xFFB5651D),
    px(756484),
  ),
  Product(
    3,
    'Floral Dress',
    'Bloom',
    'Dress',
    'Women',
    2799,
    4999,
    4.4,
    3120,
    Icons.woman,
    Color(0xFFD4537E),
    px(4380970),
  ),
  Product(
    4,
    'Cotton T-Shirt',
    'Basics',
    'T-Shirt',
    'Men',
    799,
    1499,
    4.2,
    8932,
    Icons.dry_cleaning,
    Color(0xFF1D9E75),
    px(2379005),
  ),
  Product(
    5,
    'Slim Fit Pant',
    'Urban Wear',
    'Pant',
    'Men',
    1899,
    3299,
    4.3,
    2210,
    Icons.man,
    Color(0xFF378ADD),
    px(991509),
  ),
  Product(
    6,
    'Summer Dress',
    'Bloom',
    'Dress',
    'Women',
    2299,
    3999,
    4.6,
    1543,
    Icons.woman,
    Color(0xFFBA7517),
    px(15133972),
  ),
  Product(
    7,
    'Denim Jacket',
    'Blue Denim',
    'Jacket',
    'Men',
    3299,
    5499,
    4.5,
    2987,
    Icons.checkroom,
    Color(0xFF534AB7),
    px(1072036),
  ),
  Product(
    8,
    'Basic Tee',
    'Basics',
    'T-Shirt',
    'Men',
    699,
    1299,
    4.1,
    6410,
    Icons.dry_cleaning,
    Color(0xFFA32D2D),
    px(997489),
  ),
  // ----- Mobiles / Electronics / Home -----
  // Agar koi photo na dikhe to Pexels se dusra ID daal do. Tab tak icon dikhega.
  Product(
    9,
    'Smartphone X',
    'TechOne',
    'Mobile',
    'Mobiles',
    14999,
    19999,
    4.4,
    5210,
    Icons.smartphone,
    Color(0xFF3C5A8B),
    px(404280),
  ),
  Product(
    10,
    'Wireless Headphones',
    'SoundMax',
    'Headphone',
    'Electronics',
    1999,
    3999,
    4.3,
    4120,
    Icons.headphones,
    Color(0xFF6B3C8B),
    px(3394650),
  ),
  Product(
    11,
    'Laptop Pro 14',
    'TechOne',
    'Laptop',
    'Electronics',
    45999,
    59999,
    4.6,
    1290,
    Icons.laptop,
    Color(0xFF444444),
    px(18105),
  ),
  Product(
    12,
    'Study Lamp',
    'HomeGlow',
    'Lamp',
    'Home',
    899,
    1599,
    4.2,
    980,
    Icons.lightbulb,
    Color(0xFFBA7517),
    px(1112598),
  ),
  Product(
    13,
    'Cushion Set',
    'HomeGlow',
    'Decor',
    'Home',
    1299,
    2199,
    4.4,
    760,
    Icons.chair,
    Color(0xFF1D9E75),
    px(1866149),
  ),
];

Color tint(Color c) => Color.alphaBlend(c.withAlpha(45), Colors.white);

class NetImg extends StatelessWidget {
  final Product p;
  final String? url;
  final BoxFit fit;
  const NetImg(this.p, {super.key, this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: tint(p.color),
      alignment: Alignment.center,
      child: Icon(p.icon, size: 48, color: p.color),
    );
    return Image.network(
      url ?? p.img,
      fit: fit,
      alignment: Alignment.topCenter,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
      errorBuilder: (context, error, stack) => fallback,
    );
  }
}

// ---------- Store (cart, wishlist, orders, reviews, coupon) ----------

class CartLine {
  final Product p;
  final String size;
  int qty;
  CartLine(this.p, this.size, this.qty);
}

class Order {
  final String id;
  final List<String> items;
  final int total;
  final DateTime time = DateTime.now();
  Order(this.id, this.items, this.total);

  // Demo: har 15 second mein agla step. Real app mein ye server se aayega.
  int get step => (DateTime.now().difference(time).inSeconds ~/ 15).clamp(0, 3);
}

const trackSteps = ['Placed', 'Shipped', 'Out for delivery', 'Delivered'];

class Review {
  final String name;
  final int stars;
  final String text;
  Review(this.name, this.stars, this.text);
}

class Store extends ChangeNotifier {
  final List<CartLine> lines = [];
  final Set<int> wish = {};
  final List<Order> orders = [];
  final Map<int, List<Review>> reviews = {};
  String? coupon;

  int get count => lines.fold(0, (a, l) => a + l.qty);
  int get subTotal => lines.fold(0, (a, l) => a + l.p.price * l.qty);
  int get mrpTotal => lines.fold(0, (a, l) => a + l.p.mrp * l.qty);
  int get couponOff => coupon == 'SAVE10' ? (subTotal * 0.10).round() : 0;
  int get total => subTotal - couponOff;

  void add(Product p, String size) {
    for (final l in lines) {
      if (l.p.id == p.id && l.size == size) {
        l.qty++;
        notifyListeners();
        return;
      }
    }
    lines.add(CartLine(p, size, 1));
    notifyListeners();
  }

  void change(CartLine l, int d) {
    l.qty += d;
    if (l.qty <= 0) lines.remove(l);
    notifyListeners();
  }

  void toggleWish(Product p) {
    if (!wish.remove(p.id)) wish.add(p.id);
    notifyListeners();
  }

  bool applyCoupon(String c) {
    if (c.trim().toUpperCase() == 'SAVE10') {
      coupon = 'SAVE10';
      notifyListeners();
      return true;
    }
    return false;
  }

  void removeCoupon() {
    coupon = null;
    notifyListeners();
  }

  List<Review> reviewsFor(Product p) => reviews.putIfAbsent(
    p.id,
    () => [
      Review('Rahul S.', 5, 'Bahut badhiya quality, paisa vasool!'),
      Review('Priya K.', 4, 'Achhi hai, delivery bhi fast thi.'),
    ],
  );

  void addReview(Product p, Review r) {
    reviewsFor(p).insert(0, r);
    notifyListeners();
  }

  String placeOrder() {
    final id = 'OD${DateTime.now().millisecondsSinceEpoch % 1000000000}';
    orders.insert(
      0,
      Order(
        id,
        lines
            .map(
              (l) =>
                  '${l.p.name}${l.p.isCloth ? ' (${l.size})' : ''} x${l.qty}',
            )
            .toList(),
        total,
      ),
    );
    lines.clear();
    coupon = null;
    notifyListeners();
    return id;
  }
}

final Store store = Store();

// ---------- Small shared widgets ----------

AppBar blueBar(String title, {List<Widget>? actions}) => AppBar(
  title: Text(title),
  backgroundColor: blue,
  foregroundColor: Colors.white,
  actions: actions,
);

class RatingChip extends StatelessWidget {
  final double rating;
  const RatingChip(this.rating, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: green,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$rating',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Icon(Icons.star, color: Colors.white, size: 12),
        ],
      ),
    );
  }
}

class PriceRow extends StatelessWidget {
  final Product p;
  final bool big;
  const PriceRow(this.p, {super.key, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          '₹${p.price}',
          style: TextStyle(
            fontSize: big ? 24 : 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '₹${p.mrp}',
          style: TextStyle(
            fontSize: big ? 15 : 12,
            color: Colors.grey,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        Text(
          '${p.off}% off',
          style: TextStyle(
            fontSize: big ? 15 : 12,
            color: green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class HeartButton extends StatelessWidget {
  final Product p;
  const HeartButton(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final on = store.wish.contains(p.id);
        return GestureDetector(
          onTap: () => store.toggleWish(p),
          child: CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white,
            child: Icon(
              on ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: on ? Colors.red : Colors.grey,
            ),
          ),
        );
      },
    );
  }
}

Widget priceRow(String a, String b, {Color? color, bool bold = false}) {
  final style = TextStyle(
    color: color,
    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    fontSize: bold ? 16 : 14,
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(a, style: style),
        Text(b, style: style),
      ],
    ),
  );
}

void openProduct(BuildContext context, Product p) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DetailPage(product: p)),
  );
}

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return GestureDetector(
      onTap: () => openProduct(context, p),
      child: Container(
        color: card(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: NetImg(p)),
                  Positioned(top: 6, right: 6, child: HeartButton(p)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    p.brand,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      RatingChip(p.rating),
                      Text(
                        '  (${p.reviews})',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  PriceRow(p),
                  const Text(
                    'Free delivery',
                    style: TextStyle(color: green, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Photo slider with zoom ----------

class Gallery extends StatefulWidget {
  final Product p;
  const Gallery(this.p, {super.key});

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  int i = 0;

  @override
  Widget build(BuildContext context) {
    final imgs = widget.p.gallery;
    return Stack(
      children: [
        PageView.builder(
          itemCount: imgs.length,
          onPageChanged: (v) => setState(() => i = v),
          itemBuilder: (context, k) => InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: NetImg(widget.p, url: imgs[k], fit: BoxFit.contain),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int k = 0; k < imgs.length; k++)
                Container(
                  margin: const EdgeInsets.all(3),
                  width: i == k ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == k ? blue : Colors.grey,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------- Coupon box ----------

class CouponBox extends StatefulWidget {
  const CouponBox({super.key});

  @override
  State<CouponBox> createState() => _CouponBoxState();
}

class _CouponBoxState extends State<CouponBox> {
  final TextEditingController c = TextEditingController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.coupon != null) {
          return Container(
            color: card(context),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: green),
                Expanded(
                  child: Text(
                    '  ${store.coupon} applied: ₹${store.couponOff} off',
                    style: const TextStyle(
                      color: green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: store.removeCoupon,
                  child: const Text('REMOVE'),
                ),
              ],
            ),
          );
        }
        return Container(
          color: card(context),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: c,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Coupon code (try SAVE10)',
                    border: InputBorder.none,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final ok = store.applyCoupon(c.text);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid coupon code')),
                    );
                  } else {
                    c.clear();
                  }
                },
                child: const Text('APPLY'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Write review dialog ----------

void writeReview(BuildContext context, Product p) {
  int stars = 5;
  final c = TextEditingController();
  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setS) => AlertDialog(
        title: const Text('Write a review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 1; i <= 5; i++)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setS(() => stars = i),
                    icon: Icon(
                      i <= stars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  ),
              ],
            ),
            TextField(
              controller: c,
              decoration: const InputDecoration(hintText: 'Apna review likho'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                store.addReview(p, Review('You', stars, c.text.trim()));
              }
              Navigator.pop(context);
            },
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    ),
  );
}

// ---------- App ----------

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkMode,
      builder: (context, dark, _) => MaterialApp(
        title: 'Style Shop',
        debugShowCheckedModeBanner: false,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: blue),
          scaffoldBackgroundColor: bg,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: blue,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        builder: (context, child) => ColoredBox(
          color: const Color(0xFFDDDDDD),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child,
            ),
          ),
        ),
        home: const RootPage(),
      ),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeTab(),
      const WishlistPage(),
      const OrdersPage(),
      const CartPage(),
    ];
    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: ListenableBuilder(
        listenable: store,
        builder: (context, _) => NavigationBar(
          selectedIndex: tab,
          backgroundColor: card(context),
          indicatorColor: const Color(0xFFDCE8FD),
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: blue),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('${store.wish.length}'),
                isLabelVisible: store.wish.isNotEmpty,
                child: const Icon(Icons.favorite_border),
              ),
              selectedIcon: const Icon(Icons.favorite, color: blue),
              label: 'Wishlist',
            ),
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: blue),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('${store.count}'),
                isLabelVisible: store.count > 0,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: const Icon(Icons.shopping_cart, color: blue),
              label: 'Cart',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Home ----------

const banners = [
  (
    'Mega Fashion Sale',
    'Up to 60% off on top brands',
    Color(0xFF2874F0),
    Color(0xFF6FA0FF),
  ),
  (
    'New Arrivals',
    'Fresh styles every single day',
    Color(0xFFFB641B),
    Color(0xFFFFA471),
  ),
  (
    'Free Delivery',
    'On all orders above ₹499',
    Color(0xFF388E3C),
    Color(0xFF7CCB80),
  ),
];

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final PageController pc = PageController(viewportFraction: 0.92);
  Timer? timer;
  int page = 0;
  String filter = 'All';
  String query = '';
  final GlobalKey gridKey = GlobalKey();
  final TextEditingController searchCtrl = TextEditingController();

  // sort / filter
  String sort = 'Relevance';
  String brandF = 'All';
  double minRating = 0;
  double maxPrice = 60000;

  // voice search
  final stt.SpeechToText speech = stt.SpeechToText();
  bool listening = false;

  void scrollToGrid() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = gridKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void pick(String c) {
    setState(() => filter = c);
    scrollToGrid();
  }

  Future<void> startVoice() async {
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    final ok = await speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) {
          setState(() => listening = false);
        }
      },
      onError: (e) {
        if (mounted) setState(() => listening = false);
      },
    );
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mic permission allow karo (phone ya browser mein)'),
        ),
      );
      return;
    }
    setState(() => listening = true);
    speech.listen(
      onResult: (r) {
        searchCtrl.text = r.recognizedWords;
        searchCtrl.selection = TextSelection.collapsed(
          offset: searchCtrl.text.length,
        );
        setState(() => query = r.recognizedWords);
        if (r.finalResult) scrollToGrid();
      },
    );
  }

  void openSort() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final s in [
            'Relevance',
            'Price: Low to High',
            'Price: High to Low',
            'Rating',
            'Discount',
          ])
            ListTile(
              title: Text(s),
              trailing: sort == s ? const Icon(Icons.check, color: blue) : null,
              onTap: () {
                setState(() => sort = s);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  void openFilter() {
    final brands = ['All', ...products.map((p) => p.brand).toSet()];
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setS) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Brand', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  for (final b in brands)
                    ChoiceChip(
                      label: Text(b),
                      selected: brandF == b,
                      onSelected: (_) {
                        setS(() => brandF = b);
                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Max price: ₹${maxPrice.round()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                min: 500,
                max: 60000,
                value: maxPrice,
                onChanged: (v) {
                  setS(() => maxPrice = v);
                  setState(() {});
                },
              ),
              Text(
                'Min rating: ${minRating.toStringAsFixed(1)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                min: 0,
                max: 5,
                divisions: 10,
                value: minRating,
                onChanged: (v) {
                  setS(() => minRating = v);
                  setState(() {});
                },
              ),
              TextButton(
                onPressed: () {
                  setS(() {
                    brandF = 'All';
                    minRating = 0;
                    maxPrice = 60000;
                  });
                  setState(() {});
                },
                child: const Text('RESET'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    updateLocation();
    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!pc.hasClients) return;
      pc.animateToPage(
        (page + 1) % banners.length,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    pc.dispose();
    searchCtrl.dispose();
    speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = products
        .where((p) => filter == 'All' || p.tag == filter || p.group == filter)
        .where(
          (p) => (p.name + p.brand).toLowerCase().contains(query.toLowerCase()),
        )
        .where((p) => brandF == 'All' || p.brand == brandF)
        .where((p) => p.rating >= minRating && p.price <= maxPrice)
        .toList();
    if (sort == 'Price: Low to High') shown.sort((a, b) => a.price - b.price);
    if (sort == 'Price: High to Low') shown.sort((a, b) => b.price - a.price);
    if (sort == 'Rating') shown.sort((a, b) => b.rating.compareTo(a.rating));
    if (sort == 'Discount') shown.sort((a, b) => b.off - a.off);

    const cats = [
      'All',
      'Men',
      'Women',
      'Mobiles',
      'Electronics',
      'Home',
      'Jacket',
      'Dress',
      'T-Shirt',
      'Pant',
    ];

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: blue,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: updateLocation,
                          child: ValueListenableBuilder<String>(
                            valueListenable: deliverTo,
                            builder: (context, v, _) => Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                Flexible(
                                  child: Text(
                                    ' $v',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.my_location,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: darkMode,
                        builder: (context, dark, _) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => darkMode.value = !darkMode.value,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              dark ? Icons.light_mode : Icons.dark_mode,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(color: Colors.black87),
                    onChanged: (v) {
                      setState(() => query = v);
                      scrollToGrid();
                    },
                    decoration: InputDecoration(
                      hintText: listening
                          ? 'Listening... bolo'
                          : 'Search for products, brands and more',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: blue),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () {
                                searchCtrl.clear();
                                setState(() => query = '');
                              },
                            )
                          : IconButton(
                              icon: Icon(
                                listening ? Icons.mic : Icons.mic_none,
                                color: listening ? Colors.red : Colors.grey,
                              ),
                              onPressed: startVoice,
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                Container(
                  color: card(context),
                  height: 98,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final c in cats)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => pick(c),
                          child: SizedBox(
                            width: 74,
                            child: Column(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: filter == c
                                          ? blue
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: ClipOval(
                                    child: c == 'All'
                                        ? Container(
                                            color: const Color(0xFFDCE8FD),
                                            child: const Icon(
                                              Icons.apps,
                                              color: blue,
                                            ),
                                          )
                                        : NetImg(
                                            products.firstWhere(
                                              (p) => p.tag == c || p.group == c,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  c,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: filter == c
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: filter == c ? blue : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: PageView.builder(
                    controller: pc,
                    itemCount: banners.length,
                    onPageChanged: (i) => setState(() => page = i),
                    itemBuilder: (context, i) {
                      final b = banners[i];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(colors: [b.$3, b.$4]),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              b.$1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              b.$2,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Shop now',
                                style: TextStyle(
                                  color: b.$3,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < banners.length; i++)
                      Container(
                        margin: const EdgeInsets.all(4),
                        width: page == i ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: page == i ? blue : Colors.grey,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
                if (shown.isNotEmpty)
                  Container(
                    color: card(context),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            filter == 'All'
                                ? 'Deals of the Day'
                                : 'Deals on $filter',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 220,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              for (final p in shown.reversed)
                                GestureDetector(
                                  onTap: () => openProduct(context, p),
                                  child: Container(
                                    width: 130,
                                    margin: const EdgeInsets.only(right: 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                          ),
                                        ),
                                        Text(
                                          '${p.off}% off',
                                          style: const TextStyle(
                                            color: green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'From ₹${p.price}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
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
                  ),
                Padding(
                  key: gridKey,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Text(
                    filter == 'All'
                        ? 'Top picks for you'
                        : '$filter collection (${shown.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: openSort,
                        icon: const Icon(Icons.sort, size: 18),
                        label: Text(sort),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: openFilter,
                        icon: const Icon(Icons.filter_list, size: 18),
                        label: const Text('Filter'),
                      ),
                    ],
                  ),
                ),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No products found')),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.56,
                        ),
                    itemCount: shown.length,
                    itemBuilder: (context, i) => ProductCard(product: shown[i]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Wishlist & Orders ----------

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: blueBar('My Wishlist'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = products
              .where((p) => store.wish.contains(p.id))
              .toList();
          if (items.isEmpty) {
            return const Center(
              child: Text('Tap the heart on a product to save it here'),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.56,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => ProductCard(product: items[i]),
          );
        },
      ),
    );
  }
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: blueBar('My Orders'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.orders.isEmpty) {
            return const Center(child: Text('No orders yet'));
          }
          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final o in store.orders)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  color: card(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            o.id,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            trackSteps[o.step],
                            style: const TextStyle(
                              color: green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final it in o.items)
                        Text(it, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 6),
                      Text(
                        'Total ₹${o.total}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TrackPage(order: o),
                          ),
                        ),
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: const Text('TRACK ORDER'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------- Order tracking ----------

class TrackPage extends StatefulWidget {
  final Order order;
  const TrackPage({super.key, required this.order});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  late final Timer t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      appBar: blueBar('Track ${o.id}'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (int i = 0; i < trackSteps.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(
                      i <= o.step
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: i <= o.step ? green : Colors.grey,
                    ),
                    if (i < trackSteps.length - 1)
                      Container(
                        width: 2,
                        height: 40,
                        color: i < o.step ? green : Colors.grey,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    trackSteps[i],
                    style: TextStyle(
                      fontWeight: i == o.step
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------- Product details ----------

class DetailPage extends StatefulWidget {
  final Product product;
  const DetailPage({super.key, required this.product});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  String size = 'M';

  Widget section(List<Widget> children) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(16),
    color: card(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final chosen = p.isCloth ? size : 'Standard';
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: blueBar(p.brand),
      body: ListView(
        children: [
          Container(
            color: card(context),
            height: 340,
            child: Stack(
              children: [
                Positioned.fill(child: Gallery(p)),
                Positioned(top: 10, right: 10, child: HeartButton(p)),
              ],
            ),
          ),
          section([
            Text(
              p.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                RatingChip(p.rating),
                Text(
                  '  ${p.reviews} ratings',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            PriceRow(p, big: true),
            const Text(
              'Inclusive of all taxes',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ]),
          section([
            const Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: green),
                Text(
                  '  Free delivery by tomorrow, 10 AM',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.replay, color: Colors.grey),
                Text(
                  '  7 days easy returns',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ]),
          section([
            const Text(
              'Available offers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final o in [
              'Bank Offer: 10% instant discount on UPI payments',
              'Coupon: Use SAVE10 to get extra 10% off at cart',
              'No cost EMI on orders above ₹3,000',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.local_offer, color: green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(o)),
                  ],
                ),
              ),
          ]),
          if (p.isCloth)
            section([
              const Text(
                'Select size',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in ['S', 'M', 'L', 'XL', 'XXL'])
                    ChoiceChip(
                      label: Text(s),
                      selected: size == s,
                      showCheckmark: false,
                      selectedColor: blue,
                      labelStyle: TextStyle(
                        color: size == s ? Colors.white : null,
                      ),
                      onSelected: (_) => setState(() => size = s),
                    ),
                ],
              ),
            ]),
          section([
            const Text(
              'Product details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${p.name} by ${p.brand}. Soft, comfortable and made to last. A great everyday piece that goes with almost everything.',
              style: const TextStyle(color: Colors.grey),
            ),
          ]),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => section([
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ratings & Reviews',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => writeReview(context, p),
                    child: const Text('WRITE REVIEW'),
                  ),
                ],
              ),
              for (final r in store.reviewsFor(p))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            r.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          for (int i = 0; i < 5; i++)
                            Icon(
                              i < r.stars ? Icons.star : Icons.star_border,
                              size: 14,
                              color: Colors.amber,
                            ),
                        ],
                      ),
                      Text(r.text, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: card(context),
                    foregroundColor: onSurface,
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: () {
                    store.add(p, chosen);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${p.name}${p.isCloth ? ' ($size)' : ''} added to cart',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Text(
                    'ADD TO CART',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 56,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: () {
                    store.add(p, chosen);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CheckoutPage()),
                    );
                  },
                  child: const Text(
                    'BUY NOW',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Cart ----------

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: blueBar('My Cart'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.lines.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 72,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text('Your cart is empty'),
                ],
              ),
            );
          }
          final saved = store.mrpTotal - store.total;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    for (final l in List<CartLine>.from(store.lines))
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        color: card(context),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 80,
                                height: 100,
                                child: NetImg(l.p),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.p.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (l.p.isCloth)
                                    Text(
                                      'Size: ${l.size}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  PriceRow(l.p),
                                  Row(
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        onPressed: () => store.change(l, -1),
                                      ),
                                      Text(
                                        '${l.qty}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        onPressed: () => store.change(l, 1),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () =>
                                            store.change(l, -l.qty),
                                        child: const Text('REMOVE'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const CouponBox(),
                    Container(
                      padding: const EdgeInsets.all(14),
                      color: card(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PRICE DETAILS',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          priceRow(
                            'Price (${store.count} items)',
                            '₹${store.mrpTotal}',
                          ),
                          priceRow(
                            'Discount',
                            '- ₹${store.mrpTotal - store.subTotal}',
                            color: green,
                          ),
                          if (store.couponOff > 0)
                            priceRow(
                              'Coupon (SAVE10)',
                              '- ₹${store.couponOff}',
                              color: green,
                            ),
                          priceRow('Delivery charges', 'FREE', color: green),
                          const Divider(),
                          priceRow(
                            'Total amount',
                            '₹${store.total}',
                            bold: true,
                          ),
                          const Divider(),
                          Text(
                            'You will save ₹$saved on this order',
                            style: const TextStyle(
                              color: green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: card(context),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${store.mrpTotal}',
                            style: const TextStyle(
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '₹${store.total}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CheckoutPage()),
                      ),
                      child: const Text('PLACE ORDER'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------- Checkout ----------

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String pay = 'UPI';
  final name = TextEditingController(text: 'Your Name');
  final addr = TextEditingController(text: 'House 12, Model Town, Amritsar');
  final pin = TextEditingController(text: '143001');

  @override
  void dispose() {
    name.dispose();
    addr.dispose();
    pin.dispose();
    super.dispose();
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
                    'Coupon (SAVE10)',
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
                onPressed: store.lines.isEmpty
                    ? null
                    : () {
                        final id = store.placeOrder();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SuccessPage(orderId: id, pay: pay),
                          ),
                          (r) => r.isFirst,
                        );
                      },
                child: Text(
                  'PAY ₹${store.total}',
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

class SuccessPage extends StatelessWidget {
  final String orderId;
  final String pay;
  const SuccessPage({super.key, required this.orderId, required this.pay});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: green, size: 96),
              const SizedBox(height: 12),
              const Text(
                'Order placed!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('Order ID: $orderId'),
              Text('Payment: $pay'),
              const SizedBox(height: 4),
              const Text('Arriving tomorrow', style: TextStyle(color: green)),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                ),
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Continue shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
