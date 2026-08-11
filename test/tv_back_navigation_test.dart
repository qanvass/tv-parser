import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mbark_iptv/helpers/tv_back_navigation.dart';

void main() {
  setUp(() {
    TvBackTelemetry.reset();
    TvBackGate.resetShellSuppress();
  });

  group('isTvBackKey', () {
    test('treats goBack and escape as Back', () {
      expect(isTvBackKey(LogicalKeyboardKey.goBack), isTrue);
      expect(isTvBackKey(LogicalKeyboardKey.escape), isTrue);
      expect(isTvBackKey(LogicalKeyboardKey.select), isFalse);
    });
  });

  group('decideTvBack', () {
    test('in-flight exit always ignores', () {
      expect(
        decideTvBack(backInFlight: true, panelOpen: true),
        TvBackDecision.ignoreDuplicate,
      );
      expect(
        decideTvBack(backInFlight: true, panelOpen: false),
        TvBackDecision.ignoreDuplicate,
      );
    });

    test('same-press window ignores even if panel already closed', () {
      expect(
        decideTvBack(
          backInFlight: false,
          panelOpen: false,
          sinceLastBack: const Duration(milliseconds: 20),
        ),
        TvBackDecision.ignoreDuplicate,
      );
    });

    test('open panel closes without popping', () {
      expect(
        decideTvBack(backInFlight: false, panelOpen: true),
        TvBackDecision.closePanel,
      );
    });

    test('visible player pops exactly one route', () {
      expect(
        decideTvBack(backInFlight: false, panelOpen: false),
        TvBackDecision.popRoute,
      );
    });
  });

  group('TvBackGate', () {
    test('second call within same press is blocked', () {
      var t = DateTime(2026, 8, 11, 10);
      final gate = TvBackGate(now: () => t);

      expect(gate.allow(screen: 'MoviePlayer', source: 'focus'), isTrue);
      expect(gate.allow(screen: 'MoviePlayer', source: 'popScope'), isFalse);
      expect(TvBackTelemetry.lastAction, 'blockedDuplicate');
      expect(TvBackTelemetry.lastBlockedDuplicate, isTrue);
    });

    test('markRouteExit never allows another pop', () {
      var t = DateTime(2026, 8, 11, 10);
      final gate = TvBackGate(now: () => t);

      expect(gate.allow(screen: 'MoviePlayer', source: 'focus'), isTrue);
      gate.markRouteExit();
      t = t.add(const Duration(seconds: 2));
      expect(gate.allow(screen: 'MoviePlayer', source: 'popScope'), isFalse);
      expect(gate.backInFlight, isTrue);
    });

    test('after debounce a new press may close then later pop', () {
      var t = DateTime(2026, 8, 11, 10);
      final gate = TvBackGate(now: () => t);

      expect(gate.allow(screen: 'MoviePlayer', source: 'focus'), isTrue);
      t = t.add(const Duration(milliseconds: 350));
      expect(gate.allow(screen: 'MoviePlayer', source: 'focus'), isTrue);
    });

    test('noteRoutePopped suppresses shell exit briefly', () {
      TvBackGate.noteRoutePopped();
      expect(TvBackGate.shouldSuppressShellExit(), isTrue);
      expect(
        TvBackGate.shouldSuppressShellExit(
          DateTime.now().add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });
  });

  group('playerBackCount telemetry', () {
    test('one physical Back logs exactly one popRoute', () {
      final gate = TvBackGate();
      var panelOpen = true;
      var exits = 0;

      void handle(String source) {
        if (!gate.allow(screen: 'MoviePlayer', source: source)) return;
        if (panelOpen) {
          panelOpen = false;
          logTvBack(
            screen: 'MoviePlayer',
            source: source,
            action: 'closePanel',
            blockedDuplicate: false,
            routeBefore: '/MoviePlayerScreen',
          );
          return;
        }
        gate.markRouteExit();
        exits += 1;
        logTvBack(
          screen: 'MoviePlayer',
          source: source,
          action: 'popRoute',
          blockedDuplicate: false,
          routeBefore: '/MoviePlayerScreen',
          routeAfter: '/MovieContent',
        );
      }

      handle('focus');
      handle('popScope');
      expect(exits, 0);
      expect(panelOpen, isFalse);
      expect(TvBackTelemetry.playerBackCount, 0);

      TvBackTelemetry.reset();
      final gate2 = TvBackGate(
        now: () => DateTime.now().add(const Duration(seconds: 1)),
      );
      var exits2 = 0;
      void handle2(String source) {
        if (!gate2.allow(screen: 'MoviePlayer', source: source)) return;
        gate2.markRouteExit();
        exits2 += 1;
        logTvBack(
          screen: 'MoviePlayer',
          source: source,
          action: 'popRoute',
          blockedDuplicate: false,
          routeBefore: '/MoviePlayerScreen',
          routeAfter: '/MovieContent',
        );
      }

      handle2('focus');
      handle2('popScope');
      expect(exits2, 1);
      expect(TvBackTelemetry.playerBackCount, 1);
      expect(TvBackTelemetry.lastRouteBefore, '/MoviePlayerScreen');
      expect(TvBackTelemetry.lastRouteAfter, '/MovieContent');
    });
  });

  testWidgets('Focus + PopScope same Back pops one route only', (tester) async {
    TvBackTelemetry.reset();
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: Text('shell')),
        getPages: [
          GetPage(name: '/', page: () => const Scaffold(body: Text('shell'))),
          GetPage(name: '/player', page: () => const _BackHarness()),
        ],
      ),
    );

    Get.toNamed('/player');
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);

    final state = tester.state<_BackHarnessState>(find.byType(_BackHarness));
    state.simulatePhysicalBack();
    await tester.pumpAndSettle();

    expect(find.text('player'), findsNothing);
    expect(find.text('shell'), findsOneWidget);
    expect(state.exitCount, 1);
    expect(TvBackTelemetry.playerBackCount, 1);
  });
}

class _BackHarness extends StatefulWidget {
  const _BackHarness();

  @override
  State<_BackHarness> createState() => _BackHarnessState();
}

class _BackHarnessState extends State<_BackHarness> {
  final _gate = TvBackGate();
  int exitCount = 0;

  void simulatePhysicalBack() {
    _handle('focus');
    _handle('popScope');
  }

  void _handle(String source) {
    if (!mounted) return;
    if (!_gate.allow(screen: 'MoviePlayer', source: source)) return;
    if (_gate.backInFlight) return;
    if (!Navigator.of(context).canPop()) return;
    _gate.markRouteExit();
    exitCount += 1;
    logTvBack(
      screen: 'MoviePlayer',
      source: source,
      action: 'popRoute',
      blockedDuplicate: false,
      routeBefore: '/player',
      routeAfter: '/',
    );
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handle('popScope');
      },
      child: const Scaffold(body: Text('player')),
    );
  }
}
