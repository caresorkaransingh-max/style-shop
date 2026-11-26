import 'dart:io';

// Chalane ka tarika (project folder mein):  dart run make_responsive.dart

void main() {
  final f = File('lib/main.dart');
  if (!f.existsSync()) {
    print('lib/main.dart nahi mila. Terminal ko my_first_app folder mein kholo.');
    return;
  }
  var t = f.readAsStringSync().replaceAll('\r\n', '\n');
  if (t.contains('class FrameWidth')) {
    print('Ye badlaav pehle se lage hue hain. Dobara chalane ki zaroorat nahi.');
    return;
  }
  File('main_backup_responsive.txt').writeAsStringSync(t);
  var total = 0;
  var failed = 0;

  void rep(String a, String b, {bool all = false}) {
    total++;
    if (!t.contains(a)) {
      print('NAHI MILA: ${a.trim().split('\n').first}');
      failed++;
      return;
    }
    t = all ? t.replaceAll(a, b) : t.replaceFirst(a, b);
  }

  // 1. Window ki chaudai: 480 se badhakar 1200 (tabs) aur 720 (andar ke pages)
  rep(r'''            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child,
            ),''', r'''            child: FrameWidth(child: child),''');
  rep(r'''home: const RootPage(),''', r'''navigatorObservers: [WidthObserver()],
        home: const RootPage(),''');

  // 2. Products grid: jitni jagah utne columns (phone par 2, bade window par 5)
  rep(r'''SliverGridDelegateWithFixedCrossAxisCount(''',
      r'''SliverGridDelegateWithMaxCrossAxisExtent(''', all: true);
  rep(r'''crossAxisCount: 2,''', r'''maxCrossAxisExtent: 230,''', all: true);

  t = t.trimRight() + '\n' + extraCode;
  f.writeAsStringSync(t);
  if (failed == 0) {
    print('Sab ho gaya: $total badlaav lag gaye. Ab app chalao (F5).');
  } else {
    print('${total - failed}/$total badlaav lage. Upar jo NAHI MILA likha hai uska screenshot bhejo.');
    print('Purani file main_backup_responsive.txt mein safe hai.');
  }
}

const extraCode = r'''
// ---------- Desktop / window support ----------

final ValueNotifier<double> frameWidth = ValueNotifier<double>(1200);

class WidthObserver extends NavigatorObserver {
  void _set(Route<dynamic>? r) {
    final w = (r == null || r.isFirst) ? 1200.0 : 720.0;
    WidgetsBinding.instance.addPostFrameCallback((_) => frameWidth.value = w);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _set(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(previousRoute);
}

class FrameWidth extends StatelessWidget {
  final Widget? child;
  const FrameWidth({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: frameWidth,
      builder: (context, w, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: w, end: w),
        duration: const Duration(milliseconds: 250),
        builder: (context, v, c) => ConstrainedBox(constraints: BoxConstraints(maxWidth: v), child: c),
        child: child,
      ),
    );
  }
}
''';
