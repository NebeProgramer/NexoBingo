import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import 'settings.dart';

// TODO Anderson: reemplaza esto con tu enlace real (Ko-fi, Buy Me a Coffee, PayPal.me...).
const _coffeeUrl = 'https://www.buymeacoffee.com/tu-usuario';
const _coffeePostpone = Duration(days: 15);

const _releasesApi = 'https://api.github.com/repos/NebeProgramer/NexoBingo/releases/latest';
// TODO Anderson: actualiza este link cuando corrijas el del portafolio.
const _downloadUrl = 'https://repositorio-aeop.onrender.com/desktop/VirtualBingo';

/// Cartel "invítame un café" (port de `CoffeeDialog.java`): aparece al
/// abrir la app y, si se pospone, no vuelve a salir en 15 días.
Future<void> maybeShowCoffee(BuildContext context, Settings settings) async {
  if (DateTime.now().isBefore(settings.coffeeDismissedUntil)) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Column(children: [
        Text('☕', style: TextStyle(fontSize: 44)),
        SizedBox(height: 8),
        Text('¿Te gustó NexoBingo?', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
      ]),
      content: const Text(
        'Si te divirtió el proyecto, considera invitarme a un café para ayudar a mejorar este tipo de herramientas.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppButton(
            label: 'Invitarme un café',
            color: AppColors.goldDark,
            height: 42,
            onPressed: () {
              launchUrl(Uri.parse(_coffeeUrl), mode: LaunchMode.externalApplication);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 10),
          AppButton(label: 'Tal vez más tarde', color: AppColors.blue, height: 42, onPressed: () => Navigator.pop(ctx)),
        ]),
      ],
    ),
  );
  await settings.postponeCoffee(_coffeePostpone);
}

/// true si [latest] (p. ej. el tag "2.1.0" o "v2.1.0") es una versión
/// mayor que [current] ("2.0.0"). Compara número por número, así "2.10.0"
/// es mayor que "2.9.0". Ignora lo que venga tras "-" o "+" ("2.1.0+2").
/// Si alguna no se puede leer, devuelve false (mejor no molestar).
bool isNewerVersion(String latest, String current) {
  List<int>? parse(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    s = s.split(RegExp(r'[-+]')).first;
    final parts = s.split('.').map(int.tryParse).toList();
    if (parts.isEmpty || parts.any((p) => p == null)) return null;
    return [for (final p in parts) p!];
  }

  final a = parse(latest);
  final b = parse(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// Chequeo de actualizaciones (port de `UpdateChecker.java`): compara la
/// versión instalada con el último release de GitHub. Falla en silencio
/// (sin internet, sin releases...). En web no aplica: siempre es la última.
Future<void> checkForUpdates(BuildContext context) async {
  if (kIsWeb) return;
  try {
    final current = (await PackageInfo.fromPlatform()).version;
    final response = await http
        .get(Uri.parse(_releasesApi), headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 4));
    if (response.statusCode != 200) return;
    final tag = (jsonDecode(response.body) as Map<String, dynamic>)['tag_name'] as String?;
    if (tag == null) return;
    // Solo avisar si la release publicada es MÁS NUEVA que la instalada.
    if (!isNewerVersion(tag, current) || !context.mounted) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Actualización disponible'),
        content: Text('Hay una nueva versión disponible: $tag\n¿Deseas ir a la página de descarga?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
        ],
      ),
    );
    if (go == true) await launchUrl(Uri.parse(_downloadUrl), mode: LaunchMode.externalApplication);
  } catch (_) {
    // Sin internet, timeout o error de la API: no molestar.
  }
}
