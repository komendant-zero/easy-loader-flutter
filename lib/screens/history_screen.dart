import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/download_provider.dart';

class HistoryScreen extends ConsumerWidget {
  HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(themeProvider);
    final themeData = AppThemeData.fromPreset(preset);

    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: themeData.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: themeData.textColor),
        title: Text(
          'История загрузок',
          style: GoogleFonts.outfit(
            color: themeData.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: themeData.textColor),
            onPressed: () {
              ref.read(historyProvider.notifier).clear();
            },
          )
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Text(
                'История пуста',
                style: GoogleFonts.inter(
                  color: themeData.secondaryTextColor,
                  fontSize: 16,
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = history[index];
                return Container(
                  decoration: BoxDecoration(
                    color: themeData.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xFF24243A)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                        child: SizedBox(
                          width: 120,
                          height: 80,
                          child: CachedNetworkImage(
                            imageUrl: item.thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                            ),
                            errorWidget: (context, url, error) => Icon(Icons.error, color: themeData.textColor),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: themeData.textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: themeData.primaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.type.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    color: themeData.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
