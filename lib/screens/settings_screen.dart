import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _customSavePath;

  @override
  void initState() {
    super.initState();
    _loadCustomPath();
  }

  Future<void> _loadCustomPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customSavePath = prefs.getString('custom_save_path');
    });
  }

  Future<void> _pickSavePath() async {
    final String? path = await getDirectoryPath();
    if (path != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_save_path', path);
      setState(() {
        _customSavePath = path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = ref.watch(themeProvider);
    final themeData = AppThemeData.fromPreset(preset);
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;

    return Scaffold(
      backgroundColor: themeData.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeData.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: themeData.textColor),
        title: Text(
          'Настройки',
          style: GoogleFonts.outfit(color: themeData.textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (isDesktop) ...[
            Text(
              'ПУТЬ СОХРАНЕНИЯ',
              style: GoogleFonts.outfit(color: themeData.secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeData.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeData.cardColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _customSavePath ?? 'Стандартная папка Загрузки (Downloads)',
                    style: GoogleFonts.inter(color: themeData.textColor, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _pickSavePath,
                      icon: Icon(Icons.folder, color: themeData.primaryButtonTextColor),
                      label: Text(
                        'ИЗМЕНИТЬ ПАПКУ',
                        style: GoogleFonts.outfit(color: themeData.primaryButtonTextColor, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeData.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
          Text(
            'ОФОРМЛЕНИЕ',
            style: GoogleFonts.outfit(color: themeData.secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...AppThemePreset.values.map((p) {
            final tData = AppThemeData.fromPreset(p);
            return GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).setTheme(p),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tData.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: preset == p ? tData.primaryColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: tData.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      p.name.toUpperCase(),
                      style: GoogleFonts.outfit(color: tData.textColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    if (preset == p)
                      Icon(Icons.check_circle, color: tData.primaryColor),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
