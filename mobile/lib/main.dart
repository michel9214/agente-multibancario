import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'widgets/connectivity_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_PE', null);

  // Optimize for low-RAM devices
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: AgenteMultibancoApp()));
}

class AgenteMultibancoApp extends ConsumerWidget {
  const AgenteMultibancoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Agente Multibanco',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Reduce memory usage by limiting image cache
      builder: (context, child) {
        // Limit image cache for low-RAM devices
        PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
        PaintingBinding.instance.imageCache.maximumSize = 50;

        return Column(
          children: [
            const ConnectivityBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
