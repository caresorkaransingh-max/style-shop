import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'web_helper_stub.dart'
    if (dart.library.html) 'web_helper_web.dart' as web_helper;
import 'main.dart';

const String kSupabaseUrl = 'https://fforcyaoyscgjdbtqpvp.supabase.co';
const String kSupabaseAnonKey =
    'sb_publishable_vUttKc25oC5lTNxS8ikaAQ_3gNH3V7g';

const String kStoreDataTable = 'store_user_data';
const String kStoreProductsTable = 'store_products';
const String kStoreOrdersTable = 'store_orders';
const String kProductImagesBucket = 'product-images';
const String kDefaultStoreUserKey = 'default_guest_user';

String _activeStoreUserKey = kDefaultStoreUserKey;

String _normalizeUserKey(String raw) {
  final clean = raw.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9._@-]'),
    '_',
  );
  return clean.isEmpty ? kDefaultStoreUserKey : clean;
}

Map<String, String> _supabaseHeaders({bool preferReturn = false}) {
  return {
    'apikey': kSupabaseAnonKey,
    'Authorization': 'Bearer $kSupabaseAnonKey',
    'Content-Type': 'application/json',
    if (preferReturn) 'Prefer': 'return=representation',
  };
}

String _mimeFromFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.m4v')) return 'video/x-m4v';
  if (lower.endsWith('.ogg')) return 'video/ogg';
  return 'image/jpeg';
}

String _extFromFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot == -1 || dot == fileName.length - 1) return 'jpg';
  return fileName
      .substring(dot + 1)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

Future<String?> uploadMediaBytesToSupabase({
  required Uint8List bytes,
  required String fileName,
  String folder = 'products',
}) async {
  try {
    final ext = _extFromFileName(fileName);
    final safeExt = ext.isEmpty ? 'bin' : ext;
    final objectPath =
        '$folder/${DateTime.now().millisecondsSinceEpoch}_${bytes.length}.$safeExt';
    final uri = Uri.parse(
      '$kSupabaseUrl/storage/v1/object/$kProductImagesBucket/$objectPath',
    );
    final res = await http.post(
      uri,
      headers: {
        'apikey': kSupabaseAnonKey,
        'Authorization': 'Bearer $kSupabaseAnonKey',
        'Content-Type': _mimeFromFileName(fileName),
        'x-upsert': 'true',
      },
      body: bytes,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return '$kSupabaseUrl/storage/v1/object/public/$kProductImagesBucket/$objectPath';
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<List<Product>> fetchProductsFromSupabase() async {
  try {
    final uri = Uri.parse(
      '$kSupabaseUrl/rest/v1/$kStoreProductsTable?select=id,data&order=id.asc',
    );
    final res = await http.get(uri, headers: _supabaseHeaders());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      final loaded = <Product>[];
      for (final row in list) {
        if (row is Map && row['data'] != null) {
          final rawData = row['data'];
          final map = rawData is String
              ? Map<String, dynamic>.from(jsonDecode(rawData) as Map)
              : Map<String, dynamic>.from(rawData as Map);
          loaded.add(Product.fromJson(map));
        }
      }
      return loaded;
    } else {
      debugPrint('Supabase fetchProducts failed: HTTP ${res.statusCode} -> ${res.body}');
    }
  } catch (e) {
    debugPrint('Supabase fetchProducts error: $e');
  }
  return [];
}

Future<void> upsertProductToSupabase(Product p) async {
  try {
    final uri = Uri.parse(
      '$kSupabaseUrl/rest/v1/$kStoreProductsTable?on_conflict=id',
    );
    final variants = p.effectiveVariants;
    final allImgs = <String>[];
    for (final v in variants) {
      allImgs.addAll(v.images);
    }
    if (allImgs.isEmpty && p.img.isNotEmpty) {
      allImgs.add(p.img);
    }
    await http.post(
      uri,
      headers: _supabaseHeaders(preferReturn: true),
      body: jsonEncode([
        {
          'id': p.id,
          'product_name': p.name,
          'brand': p.brand,
          'category': p.group,
          'type_tag': p.tag,
          'sale_price': p.price,
          'mrp': p.mrp,
          'stock': p.stock,
          'color_variants': variants.map((v) => v.colorName).join(', '),
          'images': allImgs.join(', '),
          'data': p.toJson(),
        },
      ]),
    );
  } catch (_) {}
}

Future<void> deleteProductFromSupabase(int productId) async {
  try {
    final uri = Uri.parse(
      '$kSupabaseUrl/rest/v1/$kStoreProductsTable?id=eq.$productId',
    );
    await http.delete(uri, headers: _supabaseHeaders());
  } catch (_) {}
}

Future<void> deleteOrderFromSupabase(String orderId) async {
  try {
    final encodedId = Uri.encodeComponent(orderId);
    final uri = Uri.parse(
      '$kSupabaseUrl/rest/v1/$kStoreOrdersTable?order_id=eq.$encodedId',
    );
    await http.delete(uri, headers: _supabaseHeaders());
  } catch (_) {}
}

Future<void> _pushUserDataToSupabase(
  String userKey,
  Map<String, dynamic> payload,
) async {
  try {
    final uri = Uri.parse(
      '$kSupabaseUrl/rest/v1/$kStoreDataTable?on_conflict=user_key',
    );
    await http.post(
      uri,
      headers: _supabaseHeaders(preferReturn: true),
      body: jsonEncode([
        {
          'user_key': userKey,
          'payload': payload,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      ]),
    );
  } catch (_) {}
}

Future<Map<String, dynamic>?> _pullUserDataFromSupabase(String userKey) async {
  try {
    final encoded = Uri.encodeComponent(userKey);
    final uri = Uri.parse(
      '$kSupabaseUrl/rest/v1/$kStoreDataTable?user_key=eq.$encoded&select=payload&limit=1',
    );
    final res = await http.get(uri, headers: _supabaseHeaders());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final rows = jsonDecode(res.body) as List;
      if (rows.isNotEmpty && rows.first is Map) {
        final rawPayload = (rows.first as Map)['payload'];
        if (rawPayload is String) {
          return Map<String, dynamic>.from(jsonDecode(rawPayload) as Map);
        }
        if (rawPayload is Map) {
          return Map<String, dynamic>.from(rawPayload);
        }
      }
    } else {
      debugPrint('Supabase pullUserData failed: HTTP ${res.statusCode}');
    }
  } catch (e) {
    debugPrint('Supabase pullUserData error: $e');
  }
  return null;
}

class AddressItem {
  final String id;
  final String label;
  final String fullName;
  final String phone;
  final String line1;
  final String city;
  final String pincode;

  const AddressItem({
    required this.id,
    required this.label,
    required this.fullName,
    required this.phone,
    required this.line1,
    required this.city,
    required this.pincode,
  });

  String get summary => '$fullName ($phone) • $line1, $city - $pincode';

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'fullName': fullName,
        'phone': phone,
        'line1': line1,
        'city': city,
        'pincode': pincode,
      };

  factory AddressItem.fromJson(Map<String, dynamic> j) => AddressItem(
        id: (j['id'] ?? '').toString(),
        label: (j['label'] ?? 'Home').toString(),
        fullName: (j['fullName'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        line1: (j['line1'] ?? '').toString(),
        city: (j['city'] ?? '').toString(),
        pincode: (j['pincode'] ?? '').toString(),
      );
}

class ProfileState extends ChangeNotifier {
  String? loggedInUser;
  String? loggedInEmail;
  String? loggedInPhone;
  bool isAdminAuthenticated = false;
  final Map<String, String> _passwordsByUser = {};

  void setAdminAuthenticated(bool val) {
    isAdminAuthenticated = val;
    notifyListeners();
  }

  Future<void> resetUserPassword(String identifier, String newPassword) async {
    final key = _normalizeUserKey(identifier);
    _passwordsByUser[key] = newPassword;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('style_shop_passwords_v1', jsonEncode(_passwordsByUser));
  }

  Future<bool> authenticateUser({
    required String displayName,
    String? email,
    String? phone,
    required String password,
    required bool isSignup,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawPw = prefs.getString('style_shop_passwords_v1');
    if (rawPw != null && rawPw.isNotEmpty) {
      final decoded = jsonDecode(rawPw) as Map;
      decoded.forEach((k, v) => _passwordsByUser[k.toString()] = v.toString());
    }
    final key = _normalizeUserKey(email ?? phone ?? displayName);
    final savedPass = _passwordsByUser[key];
    if (!isSignup && savedPass != null && savedPass != password) {
      return false;
    }
    _passwordsByUser[key] = password;
    await prefs.setString('style_shop_passwords_v1', jsonEncode(_passwordsByUser));
    await login(displayName, email: email, phone: phone);
    return true;
  }
  List<AddressItem> addresses = [
    const AddressItem(
      id: 'addr_default',
      label: 'Home',
      fullName: 'Guest Shopper',
      phone: '9876543210',
      line1: '12 MG Road',
      city: 'Bengaluru',
      pincode: '560001',
    ),
  ];
  String selectedAddressId = 'addr_default';

  AddressItem get activeAddress => addresses.firstWhere(
        (a) => a.id == selectedAddressId,
        orElse: () => addresses.first,
      );

  Map<String, dynamic> toJson() => {
        'loggedInUser': loggedInUser,
        'loggedInEmail': loggedInEmail,
        'loggedInPhone': loggedInPhone,
        'addresses': addresses.map((a) => a.toJson()).toList(),
        'selectedAddressId': selectedAddressId,
      };

  void loadFromJson(Map<String, dynamic> j) {
    loggedInUser = j['loggedInUser']?.toString();
    loggedInEmail = j['loggedInEmail']?.toString();
    loggedInPhone = j['loggedInPhone']?.toString();
    final list = ((j['addresses'] as List?) ?? [])
        .map((e) => AddressItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (list.isNotEmpty) {
      addresses = list;
    }
    selectedAddressId =
        (j['selectedAddressId'] ?? addresses.first.id).toString();
    notifyListeners();
  }

  Future<void> login(String name, {String? email, String? phone}) async {
    final cleanName = name.trim().isEmpty ? 'Shopper' : name.trim();
    loggedInUser = cleanName;
    loggedInEmail = email?.trim().isEmpty == true ? null : email?.trim();
    loggedInPhone = phone?.trim().isEmpty == true ? null : phone?.trim();
    _activeStoreUserKey = _normalizeUserKey(
      loggedInEmail ?? loggedInPhone ?? cleanName,
    );

    final cloudData = await _pullUserDataFromSupabase(_activeStoreUserKey);
    if (cloudData != null) {
      if (cloudData['store'] is Map) {
        store.loadFromJson(
          Map<String, dynamic>.from(cloudData['store'] as Map),
        );
      }
      if (cloudData['profile'] is Map) {
        final pMap = Map<String, dynamic>.from(cloudData['profile'] as Map);
        final cloudAddrs = ((pMap['addresses'] as List?) ?? [])
            .map(
              (e) => AddressItem.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        if (cloudAddrs.isNotEmpty) {
          addresses = cloudAddrs;
          selectedAddressId =
              (pMap['selectedAddressId'] ?? cloudAddrs.first.id).toString();
        }
      }
    }

    await saveStoreToStorage();
    notifyListeners();
  }

  Future<void> logout() async {
    await saveStoreToStorage();
    loggedInUser = null;
    loggedInEmail = null;
    loggedInPhone = null;
    _activeStoreUserKey = kDefaultStoreUserKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('style_shop_profile_v1');
    notifyListeners();
  }

  void addAddress(AddressItem item) {
    addresses.add(item);
    selectedAddressId = item.id;
    saveStoreToStorage();
    notifyListeners();
  }

  void selectAddress(String id) {
    selectedAddressId = id;
    saveStoreToStorage();
    notifyListeners();
  }
}

final ProfileState profile = ProfileState();

Future<void> saveStoreToStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final storeJson = store.toJson();
    final profileJson = profile.toJson();
    await prefs.setString('style_shop_store_v1', jsonEncode(storeJson));
    await prefs.setString('style_shop_profile_v1', jsonEncode(profileJson));

    final productsJson = products.map((p) => p.toJson()).toList();
    await prefs.setString('style_shop_products_v1', jsonEncode(productsJson));

    unawaited(
      _pushUserDataToSupabase(_activeStoreUserKey, {
        'store': storeJson,
        'profile': profileJson,
      }),
    );
  } catch (_) {}
}

Future<void> saveDarkMode(bool isDark) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('style_shop_dark_v1', isDark);
  } catch (_) {}
}

Future<void> loadSaved() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    darkMode.value = prefs.getBool('style_shop_dark_v1') ?? false;

    final rawProducts = prefs.getString('style_shop_products_v1');
    if (rawProducts != null && rawProducts.isNotEmpty) {
      final list = jsonDecode(rawProducts) as List;
      final parsed = list
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      products
        ..clear()
        ..addAll(parsed);
      catalogVersion.value++;
    }

    final cloudProducts = await fetchProductsFromSupabase();
    if (cloudProducts.isNotEmpty) {
      products
        ..clear()
        ..addAll(cloudProducts);
      await prefs.setString(
        'style_shop_products_v1',
        jsonEncode(products.map((p) => p.toJson()).toList()),
      );
      catalogVersion.value++;
    }

    final rawProfile = prefs.getString('style_shop_profile_v1');
    if (rawProfile != null && rawProfile.isNotEmpty) {
      profile.loadFromJson(
        Map<String, dynamic>.from(jsonDecode(rawProfile) as Map),
      );
      if (profile.loggedInUser != null) {
        _activeStoreUserKey = _normalizeUserKey(
          profile.loggedInEmail ??
              profile.loggedInPhone ??
              profile.loggedInUser!,
        );
      }
    }

    final rawStore = prefs.getString('style_shop_store_v1');
    if (rawStore != null && rawStore.isNotEmpty) {
      store.loadFromJson(
        Map<String, dynamic>.from(jsonDecode(rawStore) as Map),
      );
    }

    final cloudUserData = await _pullUserDataFromSupabase(_activeStoreUserKey);
    if (cloudUserData != null) {
      if (cloudUserData['store'] is Map) {
        store.loadFromJson(
          Map<String, dynamic>.from(cloudUserData['store'] as Map),
        );
      }
      if (cloudUserData['profile'] is Map) {
        profile.loadFromJson(
          Map<String, dynamic>.from(cloudUserData['profile'] as Map),
        );
      }
    }
  } catch (_) {}
}

const String kAdminPasscode = 'admin123';

Future<void> openLoginPopup(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _LoginSignupDialog(),
  );
}

Future<bool> verifyAdminAccess(BuildContext context) async {
  if (profile.isAdminAuthenticated) return true;
  final pinCtrl = TextEditingController();
  String? errText;
  bool verified = false;

  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setS) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: blue),
            SizedBox(width: 8),
            Text('Admin Lock'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Only verified admins can access product management.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Admin Passcode',
                prefixIcon: const Icon(Icons.key),
                errorText: errText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (pinCtrl.text.trim() == kAdminPasscode) {
                  profile.setAdminAuthenticated(true);
                  verified = true;
                  Navigator.pop(ctx);
                } else {
                  setS(() => errText = 'Invalid admin passcode');
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: blue),
            onPressed: () {
              if (pinCtrl.text.trim() == kAdminPasscode) {
                profile.setAdminAuthenticated(true);
                verified = true;
                Navigator.pop(ctx);
              } else {
                setS(() => errText = 'Invalid admin passcode');
              }
            },
            child: const Text('UNLOCK'),
          ),
        ],
      ),
    ),
  );

  pinCtrl.dispose();
  return verified;
}

class _LoginSignupDialog extends StatefulWidget {
  const _LoginSignupDialog();

  @override
  State<_LoginSignupDialog> createState() => _LoginSignupDialogState();
}

class _LoginSignupDialogState extends State<_LoginSignupDialog> {
  bool isSignup = false;
  bool useEmailField = true;
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  String? err;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _openForgotPassword() async {
    final resetTargetCtrl = TextEditingController(
      text: emailCtrl.text.trim().isNotEmpty
          ? emailCtrl.text.trim()
          : phoneCtrl.text.trim(),
    );
    final newPassCtrl = TextEditingController();
    String? resetErr;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: blue),
              SizedBox(width: 8),
              Text('Forgot Password'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your registered Email or Phone Number and set a new password.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: resetTargetCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email or Phone Number',
                    prefixIcon: const Icon(Icons.person_search),
                    errorText: resetErr,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password (min 4 chars)',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: blue),
              onPressed: () async {
                final target = resetTargetCtrl.text.trim();
                final nextPass = newPassCtrl.text.trim();
                if (target.isEmpty) {
                  setS(() => resetErr = 'Please enter email or phone number');
                  return;
                }
                if (nextPass.length < 4) {
                  setS(() => resetErr = 'New password must be at least 4 chars');
                  return;
                }
                await profile.resetUserPassword(target, nextPass);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Password reset updated for $target'),
                  ),
                );
              },
              child: const Text('RESET PASSWORD'),
            ),
          ],
        ),
      ),
    );

    resetTargetCtrl.dispose();
    newPassCtrl.dispose();
  }

  Future<void> _submit() async {
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final pass = passCtrl.text.trim();
    final name = nameCtrl.text.trim();

    if (isSignup && name.isEmpty) {
      setState(() => err = 'Please enter your full name');
      return;
    }
    if (email.isEmpty && phone.isEmpty) {
      setState(() => err = 'Please enter Email or Phone Number');
      return;
    }
    if (pass.length < 4) {
      setState(() => err = 'Password must be at least 4 characters');
      return;
    }

    final displayName = name.isNotEmpty
        ? name
        : (email.isNotEmpty ? email.split('@').first : 'User $phone');

    final authOk = await profile.authenticateUser(
      displayName: displayName,
      email: email.isEmpty ? null : email,
      phone: phone.isEmpty ? null : phone,
      password: pass,
      isSignup: isSignup,
    );

    if (!authOk) {
      setState(() => err = 'Incorrect password for this account');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Welcome, ${profile.loggedInUser}!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 560;
    final leftPanel = Container(
      width: isNarrow ? double.infinity : 210,
      padding: const EdgeInsets.all(22),
      color: blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSignup ? 'Looks like you\'re new here!' : 'Login',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isSignup
                    ? 'Sign up with your details to get started'
                    : 'Get access to your Orders, Wishlist and Recommendations',
                style: const TextStyle(
                  color: Color(0xFFE3ECFF),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCA28),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag,
              color: Color(0xFF1F2937),
              size: 32,
            ),
          ),
        ],
      ),
    );

    final rightPanel = Container(
      width: isNarrow ? double.infinity : 330,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSignup ? 'Create your account' : 'Log in for the best experience',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isSignup) ...[
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.black87),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline, color: blue),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.black87),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined, color: blue),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: const Icon(Icons.phone_outlined, color: blue),
              suffixIcon: TextButton(
                onPressed: () => setState(() => useEmailField = !useEmailField),
                child: Text(
                  useEmailField ? 'Use Phone' : 'Use Email',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passCtrl,
            obscureText: true,
            style: const TextStyle(color: Colors.black87),
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline, color: blue),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 2),
                minimumSize: const Size(0, 28),
              ),
              onPressed: _openForgotPassword,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (err != null) ...[
            Text(
              err!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
            const SizedBox(height: 6),
          ],
          const Text(
            'By continuing, you agree to Style Shop Terms of Use and Privacy Policy.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: orange,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: _submit,
            child: Text(
              isSignup ? 'Sign Up' : 'Continue',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                isSignup = !isSignup;
                err = null;
              }),
              child: Text(
                isSignup
                    ? 'Existing User? Log in'
                    : 'New to Style Shop? Create an account',
                style: const TextStyle(
                  color: blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: SingleChildScrollView(
        child: isNarrow
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [leftPanel, rightPanel],
              )
            : IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [leftPanel, rightPanel],
                ),
              ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _openAdminPanel() async {
    final ok = await verifyAdminAccess(context);
    if (!mounted || !ok) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const AdminPanelPage()),
    );
    if (mounted) setState(() {});
  }

  void _showAddAddressDialog(BuildContext context) {
    final labelC = TextEditingController(text: 'Home');
    final nameC = TextEditingController(text: profile.loggedInUser ?? '');
    final phoneC = TextEditingController(text: profile.loggedInPhone ?? '');
    final line1C = TextEditingController();
    final cityC = TextEditingController();
    final pinC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Delivery Address'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelC,
                decoration:
                    const InputDecoration(labelText: 'Label (Home/Office)'),
              ),
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: phoneC,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: line1C,
                decoration:
                    const InputDecoration(labelText: 'House / Street / Area'),
              ),
              TextField(
                controller: cityC,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              TextField(
                controller: pinC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pincode'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty || line1C.text.trim().isEmpty) {
                return;
              }
              profile.addAddress(
                AddressItem(
                  id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
                  label: labelC.text.trim().isEmpty ? 'Home' : labelC.text.trim(),
                  fullName: nameC.text.trim(),
                  phone: phoneC.text.trim(),
                  line1: line1C.text.trim(),
                  city: cityC.text.trim(),
                  pincode: pinC.text.trim(),
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        title: const Text('My Account'),
      ),
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, _) {
          final loggedIn = profile.loggedInUser != null;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: blue,
                      child: Text(
                        (profile.loggedInUser ?? 'G')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loggedIn ? profile.loggedInUser! : 'Guest Shopper',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (profile.loggedInEmail != null)
                            Text(
                              profile.loggedInEmail!,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          if (profile.loggedInPhone != null)
                            Text(
                              profile.loggedInPhone!,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (loggedIn)
                      OutlinedButton(
                        onPressed: () => profile.logout(),
                        child: const Text('Logout'),
                      )
                    else
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: blue),
                        onPressed: () => openLoginPopup(context),
                        child: const Text('Login'),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Saved Addresses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showAddAddressDialog(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    for (final a in profile.addresses)
                      RadioListTile<String>(
                        value: a.id,
                        groupValue: profile.selectedAddressId,
                        onChanged: (v) {
                          if (v != null) profile.selectAddress(v);
                        },
                        title: Text('${a.label} • ${a.fullName}'),
                        subtitle: Text('${a.line1}, ${a.city} - ${a.pincode}'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: card(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.support_agent, color: green),
                      title: const Text('24x7 Customer Support'),
                      subtitle: const Text('Chat with support assistant'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openSupportChat(context),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _openAdminPanel,
                          icon: const Icon(Icons.admin_panel_settings),
                          label: const Text(
                            'Open Store Admin',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
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

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String pay = 'UPI';

  @override
  Widget build(BuildContext context) {
    final addr = profile.activeAddress;
    return Scaffold(
      appBar: blueBar('Checkout'),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              color: card(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DELIVERY ADDRESS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${addr.label} • ${addr.fullName} (${addr.phone})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${addr.line1}, ${addr.city} - ${addr.pincode}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              color: card(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAYMENT METHOD',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  for (final m in [
                    'UPI',
                    'Credit / Debit Card',
                    'Cash on Delivery',
                  ])
                    RadioListTile<String>(
                      value: m,
                      groupValue: pay,
                      onChanged: (v) {
                        if (v != null) setState(() => pay = v);
                      },
                      title: Text(m),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const CouponBox(),
            Container(
              padding: const EdgeInsets.all(14),
              color: card(context),
              child: Column(
                children: [
                  priceRow('Items (${store.count})', '₹${store.mrpTotal}'),
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
                  priceRow('Delivery', 'FREE', color: green),
                  const Divider(),
                  priceRow('Payable Amount', '₹${store.total}', bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                final id = store.placeOrder();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SuccessPage(orderId: id, pay: pay),
                  ),
                );
              },
              child: const Text(
                'CONFIRM ORDER',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
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
  if (c == 'FLAT200') return subTotal >= 500 ? 200 : 0;
  if (c == 'WELCOME') return (subTotal * 0.15).round().clamp(0, 500);
  return 0;
}

class SaleTimer extends StatefulWidget {
  const SaleTimer({super.key});

  @override
  State<SaleTimer> createState() => _SaleTimerState();
}

class _SaleTimerState extends State<SaleTimer> {
  Duration rem = const Duration(hours: 3, minutes: 42, seconds: 19);
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (rem.inSeconds > 0) {
          rem -= const Duration(seconds: 1);
        } else {
          rem = const Duration(hours: 4);
        }
      });
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = rem.inHours.toString().padLeft(2, '0');
    final m = (rem.inMinutes % 60).toString().padLeft(2, '0');
    final s = (rem.inSeconds % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        'Ends in $h:$m:$s',
        style: const TextStyle(
          color: orange,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

final ValueNotifier<List<Product>> _recentNotifier =
    ValueNotifier<List<Product>>([]);

void addRecent(Product p) {
  final current = List<Product>.from(_recentNotifier.value)
    ..removeWhere((e) => e.id == p.id)
    ..insert(0, p);
  if (current.length > 8) {
    current.removeRange(8, current.length);
  }
  _recentNotifier.value = current;
}

class RecentlyViewed extends StatelessWidget {
  const RecentlyViewed({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Product>>(
      valueListenable: _recentNotifier,
      builder: (context, items, _) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Container(
          color: card(context),
          margin: const EdgeInsets.only(top: 10),
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
                height: 185,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final p in items)
                      GestureDetector(
                        onTap: () => openProduct(context, p),
                        child: Container(
                          width: 120,
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '₹${p.price}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
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
        );
      },
    );
  }
}

class SimilarProductsSection extends StatelessWidget {
  final Product currentProduct;
  const SimilarProductsSection({super.key, required this.currentProduct});

  @override
  Widget build(BuildContext context) {
    final similar = products
        .where(
          (p) =>
              p.id != currentProduct.id &&
              (p.tag == currentProduct.tag || p.group == currentProduct.group),
        )
        .take(6)
        .toList();
    if (similar.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Similar Products',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 205,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in similar)
                  GestureDetector(
                    onTap: () => openProduct(context, p),
                    child: Container(
                      width: 135,
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
                          const SizedBox(height: 6),
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '₹${p.price}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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

void showSizeChartDialog(BuildContext context, Product p) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${p.tag} Size Chart'),
      content: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 14,
          columns: const [
            DataColumn(label: Text('Size')),
            DataColumn(label: Text('Chest')),
            DataColumn(label: Text('Length')),
          ],
          rows: const [
            DataRow(cells: [
              DataCell(Text('S')),
              DataCell(Text('38"')),
              DataCell(Text('27"')),
            ]),
            DataRow(cells: [
              DataCell(Text('M')),
              DataCell(Text('40"')),
              DataCell(Text('28"')),
            ]),
            DataRow(cells: [
              DataCell(Text('L')),
              DataCell(Text('42"')),
              DataCell(Text('29"')),
            ]),
            DataRow(cells: [
              DataCell(Text('XL')),
              DataCell(Text('44"')),
              DataCell(Text('30"')),
            ]),
            DataRow(cells: [
              DataCell(Text('XXL')),
              DataCell(Text('46"')),
              DataCell(Text('31"')),
            ]),
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

void shareProductLink(BuildContext context, Product p) {
  final link = '${Uri.base.origin}${Uri.base.path}?product=${p.id}';
  Clipboard.setData(ClipboardData(text: link));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Product link copied: $link')),
  );
}

void handleDeepLinkIfAny(BuildContext context) {
  final rawId = Uri.base.queryParameters['product'];
  final pid = int.tryParse(rawId ?? '');
  if (pid == null) return;
  final match = products.where((e) => e.id == pid).firstOrNull;
  if (match != null) {
    openProduct(context, match);
  }
}

void downloadOrderInvoice(BuildContext context, Order o) {
  final buf = StringBuffer()
    ..writeln('STYLE SHOP - ORDER INVOICE')
    ..writeln('Order ID: ${o.id}')
    ..writeln('Status: ${o.statusLabel}')
    ..writeln('Items:')
    ..writeln(o.items.map((e) => ' - $e').join('\n'))
    ..writeln('Total Paid: ₹${o.total}');
  if (kIsWeb) {
    web_helper.downloadTextFile('${o.id}_invoice.txt', buf.toString());
  }
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Invoice • ${o.id}'),
      content: SingleChildScrollView(child: Text(buf.toString())),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: buf.toString()));
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invoice copied to clipboard')),
            );
          },
          child: const Text('COPY'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('CLOSE'),
        ),
      ],
    ),
  );
}

class WebVideoPlayer extends StatelessWidget {
  final String url;
  final double height;
  const WebVideoPlayer({super.key, required this.url, this.height = 300});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: web_helper.buildPlatformVideoPlayer(url, height),
      );
    }
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.black87,
      alignment: Alignment.center,
      child: Text(
        'Video preview: $url',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

void openSupportChat(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _SupportChatSheet(),
  );
}

class _SupportChatSheet extends StatefulWidget {
  const _SupportChatSheet();

  @override
  State<_SupportChatSheet> createState() => _SupportChatSheetState();
}

class _SupportChatSheetState extends State<_SupportChatSheet> {
  final msgCtrl = TextEditingController();
  final List<(bool isUser, String text)> messages = [
    (
      false,
      'Hi! Welcome to Style Shop support. Ask me about orders, returns, coupons, or delivery.',
    ),
  ];

  void _send(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    msgCtrl.clear();
    final lower = clean.toLowerCase();
    String reply =
        'Thanks for reaching out! You can track orders in the Orders tab or use coupons SAVE10 / FLAT200 / WELCOME at checkout.';
    if (lower.contains('order') || lower.contains('track')) {
      reply =
          'Open the Orders tab and tap TRACK ORDER on any order to see live delivery progress.';
    } else if (lower.contains('return') || lower.contains('refund')) {
      reply =
          'Delivered orders are eligible for a 7-day easy return from the Orders tab.';
    } else if (lower.contains('coupon') || lower.contains('discount')) {
      reply =
          'Try SAVE10 (10% off), FLAT200 (₹200 off above ₹500), or WELCOME (15% off up to ₹500).';
    }
    setState(() {
      messages.add((true, clean));
      messages.add((false, reply));
    });
  }

  @override
  void dispose() {
    msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 12,
        right: 12,
        top: 12,
      ),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Customer Support',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final (isUser, text) = messages[i];
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isUser ? blue : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: msgCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: blue),
                  onPressed: () => _send(msgCtrl.text),
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final idC = TextEditingController();
  final nameC = TextEditingController();
  final brandC = TextEditingController();
  final priceC = TextEditingController();
  final mrpC = TextEditingController();
  final stockC = TextEditingController(text: '10');
  final imgUrlC = TextEditingController();
  final videoUrlC = TextEditingController();

  String selectedGroup = 'Men';
  String selectedTag = 'Shirt';
  bool saving = false;
  bool uploading = false;
  bool uploadingVideo = false;

  static const Map<String, Color> kAllColors = {
    'Black': Color(0xFF111827),
    'White': Color(0xFFFFFFFF),
    'Off White': Color(0xFFFAF9F6),
    'Grey': Color(0xFF6B7280),
    'Charcoal': Color(0xFF374151),
    'Silver': Color(0xFFC0C0C0),
    'Navy Blue': Color(0xFF1E3A8A),
    'Royal Blue': Color(0xFF2563EB),
    'Sky Blue': Color(0xFF38BDF8),
    'Teal': Color(0xFF0D9488),
    'Turquoise': Color(0xFF06B6D4),
    'Red': Color(0xFFDC2626),
    'Maroon': Color(0xFF7F1D1D),
    'Burgundy': Color(0xFF800020),
    'Crimson': Color(0xFF991B1B),
    'Pink': Color(0xFFEC4899),
    'Baby Pink': Color(0xFFF9A8D4),
    'Magenta': Color(0xFFD946EF),
    'Purple': Color(0xFF7C3AED),
    'Lavender': Color(0xFFC4B5FD),
    'Violet': Color(0xFF5B21B6),
    'Green': Color(0xFF16A34A),
    'Olive Green': Color(0xFF4D7C0F),
    'Mint Green': Color(0xFF6EE7B7),
    'Forest Green': Color(0xFF14532D),
    'Yellow': Color(0xFFEAB308),
    'Mustard': Color(0xFFCA8A04),
    'Gold': Color(0xFFD97706),
    'Orange': Color(0xFFF97316),
    'Peach': Color(0xFFFDBA74),
    'Coral': Color(0xFFFB7185),
    'Brown': Color(0xFF78350F),
    'Tan': Color(0xFFD2B48C),
    'Beige': Color(0xFFF5F5DC),
    'Cream': Color(0xFFFFFDD0),
    'Khaki': Color(0xFFC3B091),
    'Multicolor': Color(0xFF8B5CF6),
  };

  static const List<String> kExtraCategories = [
    'Men',
    'Women',
    'Kids',
    'Boys',
    'Girls',
    'Mobiles',
    'Electronics',
    'Laptops',
    'Audio & Headphones',
    'Smart Watches',
    'Home',
    'Kitchen & Dining',
    'Furniture',
    'Decor',
    'Footwear',
    'Sports Shoes',
    'Casual Shoes',
    'Sandals & Slippers',
    'Accessories',
    'Bags & Backpacks',
    'Watches',
    'Sunglasses',
    'Jewellery',
    'Beauty & Grooming',
    'Sports & Fitness',
    'Toys & Games',
    'Books & Stationery',
  ];

  static const List<String> kExtraTags = [
    'Shirt',
    'T-Shirt',
    'Polo',
    'Top',
    'Kurti',
    'Saree',
    'Dress',
    'Jeans',
    'Trousers',
    'Shorts',
    'Track Pant',
    'Jacket',
    'Denim Jacket',
    'Hoodie',
    'Sweater',
    'Blazer',
    'Sneakers',
    'Running Shoes',
    'Heels',
    'Flats',
    'Loafers',
    'Smartphone',
    'Earbuds',
    'Headphones',
    'Smartwatch',
    'Charger & Cable',
    'Backpack',
    'Handbag',
    'Wallet',
    'Belt',
    'Watch',
    'Sunglasses',
    'Perfume',
    'Mug',
    'Bottle',
    'Bedsheet',
    'Cushion',
  ];

  final Set<String> selectedColors = {'Black'};
  final Map<String, List<String>> imagesByColor = {};
  String activeImageColor = 'Black';

  List<String> get _allAvailableCategories {
    final set = <String>{...kStoreCategories, ...kExtraCategories};
    return set.toList();
  }

  List<String> get _allAvailableTags {
    final set = <String>{...kProductTypes, ...kExtraTags};
    return set.toList();
  }

  List<String> get _activeColorImages =>
      imagesByColor.putIfAbsent(activeImageColor, () => <String>[]);

  Color _swatchForColor(String name) {
    return kAllColors[name] ?? const Color(0xFF1F2937);
  }

  @override
  void dispose() {
    idC.dispose();
    nameC.dispose();
    brandC.dispose();
    priceC.dispose();
    mrpC.dispose();
    stockC.dispose();
    imgUrlC.dispose();
    videoUrlC.dispose();
    super.dispose();
  }

  void _toggleColor(String colorName) {
    setState(() {
      if (selectedColors.contains(colorName)) {
        if (selectedColors.length > 1) {
          selectedColors.remove(colorName);
          if (activeImageColor == colorName) {
            activeImageColor = selectedColors.first;
          }
        }
      } else {
        selectedColors.add(colorName);
        activeImageColor = colorName;
      }
    });
  }

  void _fillFromProduct(Product p) {
    setState(() {
      idC.text = '${p.id}';
      nameC.text = p.name;
      brandC.text = p.brand;
      priceC.text = '${p.price}';
      mrpC.text = '${p.mrp}';
      stockC.text = '${p.stock}';
      imgUrlC.clear();
      videoUrlC.text = p.videoUrl ?? '';

      final cats = _allAvailableCategories;
      selectedGroup = cats.contains(p.group) ? p.group : cats.first;
      final tags = _allAvailableTags;
      selectedTag = tags.contains(p.tag) ? p.tag : tags.first;

      selectedColors.clear();
      imagesByColor.clear();
      for (final v in p.effectiveVariants) {
        final matchKey = kAllColors.keys.firstWhere(
          (k) => k.toLowerCase() == v.colorName.toLowerCase(),
          orElse: () => v.colorName,
        );
        selectedColors.add(matchKey);
        imagesByColor[matchKey] = List<String>.from(v.images);
      }
      if (selectedColors.isEmpty) {
        selectedColors.add('Black');
      }
      activeImageColor = selectedColors.first;
    });
  }

  void _resetFields() {
    setState(() {
      idC.clear();
      nameC.clear();
      brandC.clear();
      priceC.clear();
      mrpC.clear();
      stockC.text = '10';
      imgUrlC.clear();
      videoUrlC.clear();
      selectedColors
        ..clear()
        ..add('Black');
      imagesByColor.clear();
      activeImageColor = 'Black';
    });
  }

  void _addImageUrlToActiveColor() {
    final url = imgUrlC.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _activeColorImages.add(url);
      imgUrlC.clear();
    });
  }

  Future<void> _pickAndUploadImages() async {
    final dynamic picker = FilePicker;
    final dynamic res = await picker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (res == null) return;
    final List<dynamic> pickedFiles = (res.files as List?) ?? const [];
    if (pickedFiles.isEmpty) return;

    setState(() => uploading = true);
    int uploadedCount = 0;
    for (final f in pickedFiles) {
      final Uint8List? bytes = f.bytes as Uint8List?;
      if (bytes == null || bytes.isEmpty) continue;
      final url = await uploadMediaBytesToSupabase(
        bytes: bytes,
        fileName: f.name,
        folder: 'products',
      );
      if (url != null) {
        _activeColorImages.add(url);
        uploadedCount++;
      }
    }
    if (!mounted) return;
    setState(() => uploading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uploadedCount > 0
              ? '$uploadedCount image(s) $activeImageColor mein upload ho gayi!'
              : 'Image upload fail hui — Supabase bucket check karein',
        ),
      ),
    );
  }

  Future<void> _pickAndUploadVideo() async {
    final dynamic picker = FilePicker;
    final dynamic res = await picker.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
    );
    if (res == null) return;
    final List<dynamic> pickedFiles = (res.files as List?) ?? const [];
    if (pickedFiles.isEmpty) return;
    final dynamic f = pickedFiles.first;
    final Uint8List? bytes = f.bytes as Uint8List?;
    if (bytes == null || bytes.isEmpty) return;

    setState(() => uploadingVideo = true);
    final url = await uploadMediaBytesToSupabase(
      bytes: bytes,
      fileName: f.name,
      folder: 'videos',
    );
    if (!mounted) return;
    setState(() {
      uploadingVideo = false;
      if (url != null) videoUrlC.text = url;
    });
  }

  Future<void> _saveToSupabaseAndApp() async {
    final name = nameC.text.trim();
    final price = int.tryParse(priceC.text.trim()) ?? 0;
    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product name aur valid sale price daalein'),
        ),
      );
      return;
    }

    setState(() => saving = true);

    final parsedId = int.tryParse(idC.text.trim());
    final rowId =
        parsedId ?? ((DateTime.now().millisecondsSinceEpoch % 900000) + 100000);
    final brand = brandC.text.trim().isEmpty ? 'Style Co' : brandC.text.trim();
    final mrp = int.tryParse(mrpC.text.trim()) ?? price;
    final stock = int.tryParse(stockC.text.trim()) ?? 10;

    if (imgUrlC.text.trim().isNotEmpty) {
      _activeColorImages.add(imgUrlC.text.trim());
      imgUrlC.clear();
    }

    String fallbackImg = px(15133974);
    for (final c in selectedColors) {
      final list = imagesByColor[c];
      if (list != null && list.isNotEmpty) {
        fallbackImg = list.first;
        break;
      }
    }

    final builtVariants = <ProductVariant>[];
    final allImagesList = <String>[];
    for (final c in selectedColors) {
      final imgs = (imagesByColor[c] != null && imagesByColor[c]!.isNotEmpty)
          ? List<String>.from(imagesByColor[c]!)
          : <String>[fallbackImg];
      allImagesList.addAll(imgs);
      builtVariants.add(ProductVariant(c, _swatchForColor(c), imgs));
    }

    final firstColor = selectedColors.first;
    final primarySwatch = _swatchForColor(firstColor);

    final product = Product(
      rowId,
      name,
      brand,
      selectedTag,
      selectedGroup,
      price,
      mrp < price ? price : mrp,
      4.5,
      1,
      Icons.shopping_bag,
      primarySwatch,
      fallbackImg,
      stock: stock,
      videoUrl: videoUrlC.text.trim().isEmpty ? null : videoUrlC.text.trim(),
      variants: builtVariants,
    );

    final idx = products.indexWhere((e) => e.id == rowId);
    if (idx >= 0) {
      products[idx] = product;
    } else {
      products.insert(0, product);
    }
    catalogVersion.value++;
    await saveStoreToStorage();

    try {
      final uri = Uri.parse(
        '$kSupabaseUrl/rest/v1/$kStoreProductsTable?on_conflict=id',
      );
      final response = await http.post(
        uri,
        headers: _supabaseHeaders(preferReturn: true),
        body: jsonEncode([
          {
            'id': rowId,
            'name': name,
            'product_name': name,
            'brand': brand,
            'category': selectedGroup,
            'type_tag': selectedTag,
            'sale_price': price,
            'mrp': mrp < price ? price : mrp,
            'stock': stock,
            'color_variants': selectedColors.join(', '),
            'images': allImagesList.toSet().join(', '),
            'data': product.toJson(),
          },
        ]),
      );

      if (!mounted) return;
      setState(() => saving = false);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        idC.text = '$rowId';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supabase store_products mein save ho gaya (ID: $rowId)'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'App mein save hua, Supabase status ${response.statusCode}: ${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Supabase sync error: $e')),
      );
    }
  }

  Future<void> _removeRow(Product p) async {
    products.removeWhere((e) => e.id == p.id);
    catalogVersion.value++;
    await saveStoreToStorage();
    await deleteProductFromSupabase(p.id);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Row #${p.id} (${p.name}) delete ho gayi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _allAvailableCategories;
    final tags = _allAvailableTags;
    return Scaffold(
      appBar: blueBar('store_products Manager'),
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
                  'Add / Edit Product in store_products',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: idC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'id (khali chhodein toh auto ID banega)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: brandC,
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
                        value: categories.contains(selectedGroup)
                            ? selectedGroup
                            : categories.first,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final g in categories)
                            DropdownMenuItem(value: g, child: Text(g)),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => selectedGroup = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: tags.contains(selectedTag)
                            ? selectedTag
                            : tags.first,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Type / Sub-Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final t in tags)
                            DropdownMenuItem(value: t, child: Text(t)),
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
                        controller: priceC,
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
                        controller: mrpC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'MRP (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 84,
                      child: TextField(
                        controller: stockC,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Colors (Multiple Select Karein)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${selectedColors.length} selected',
                      style: const TextStyle(
                        color: blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in kAllColors.entries)
                      FilterChip(
                        selected: selectedColors.contains(entry.key),
                        selectedColor: blue.withOpacity(0.16),
                        checkmarkColor: blue,
                        avatar: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: entry.value,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade500,
                              width: 1,
                            ),
                          ),
                        ),
                        label: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selectedColors.contains(entry.key)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onSelected: (_) => _toggleColor(entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Upload Product Images (Selected Color ke liye)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in selectedColors)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _swatchForColor(c),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                            label: Text(
                              '$c (${(imagesByColor[c] ?? const []).length})',
                            ),
                            selected: activeImageColor == c,
                            onSelected: (_) =>
                                setState(() => activeImageColor = c),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: blue,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: uploading ? null : _pickAndUploadImages,
                        icon: const Icon(Icons.cloud_upload),
                        label: Text(
                          uploading
                              ? 'Uploading Images...'
                              : 'Upload Images ($activeImageColor)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: imgUrlC,
                        decoration: InputDecoration(
                          labelText: 'Ya Image URL paste karein ($activeImageColor)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _addImageUrlToActiveColor,
                      child: const Text('Add URL'),
                    ),
                  ],
                ),
                if (_activeColorImages.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 76,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _activeColorImages.length,
                      itemBuilder: (_, idx) {
                        final imgUrl = _activeColorImages[idx];
                        return Stack(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.network(
                                  imgUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.image, size: 24),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _activeColorImages.removeAt(idx),
                                ),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.red,
                                  child: Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: videoUrlC,
                        decoration: const InputDecoration(
                          labelText: 'Product Video URL (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: uploadingVideo ? null : _pickAndUploadVideo,
                      icon: const Icon(Icons.videocam),
                      label: Text(uploadingVideo ? '...' : 'Upload Video'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: saving ? null : _saveToSupabaseAndApp,
                        child: Text(
                          saving ? 'SAVING TO SUPABASE...' : 'SAVE PRODUCT',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _resetFields,
                      child: const Text('CLEAR'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Saved Products (${products.length})',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final p in List<Product>.from(products))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: card(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: NetImg(p),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${p.id} • ${p.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${p.group} • ${p.tag} • ₹${p.price} • Colors: ${p.effectiveVariants.map((v) => v.colorName).join(', ')}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit Product',
                    onPressed: () => _fillFromProduct(p),
                    icon: const Icon(Icons.edit, color: blue),
                  ),
                  IconButton(
                    tooltip: 'Delete Product',
                    onPressed: () => _removeRow(p),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
