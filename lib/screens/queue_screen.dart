import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/queue_provider.dart';
import '../models/queue_item.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Очередь загрузок',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          if (queue.any((e) => e.status == QueueItemStatus.done))
            TextButton(
              onPressed: () => ref.read(queueProvider.notifier).clearDone(),
              child: Text(
                'Очистить',
                style: GoogleFonts.inter(color: const Color(0xFF8A8A9E)),
              ),
            ),
        ],
      ),
      body: queue.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: queue.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = queue[index];
                return _QueueCard(item: item);
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(
            'Очередь пуста',
            style: GoogleFonts.outfit(
              color: const Color(0xFF5A5A6E),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueCard extends ConsumerWidget {
  final QueueItem item;
  const _QueueCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor(item.status),
          width: 1,
        ),
        boxShadow: [
          if (item.status == QueueItemStatus.downloading)
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Platform icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.platform == 'youtube'
                    ? const Color(0xFFFF0000).withValues(alpha: 0.1)
                    : const Color(0xFF69C9D0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: item.platform == 'youtube'
                    ? const FaIcon(FontAwesomeIcons.youtube,
                        color: Color(0xFFFF0000), size: 20)
                    : const FaIcon(FontAwesomeIcons.tiktok,
                        color: Color(0xFF69C9D0), size: 18),
              ),
            ),
            const SizedBox(width: 12),
            // Title + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.status == QueueItemStatus.downloading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        backgroundColor: const Color(0xFF1E1E2A),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF3B82F6)),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(item.progress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF3B82F6),
                        fontSize: 11,
                      ),
                    ),
                  ] else if (item.status == QueueItemStatus.error) ...[
                    Text(
                      item.error ?? 'Неизвестная ошибка',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontSize: 11,
                      ),
                    ),
                  ] else ...[
                    Text(
                      _statusLabel(item.status),
                      style: GoogleFonts.inter(
                        color: _statusColor(item.status),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action
            _buildAction(ref, item),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(WidgetRef ref, QueueItem item) {
    switch (item.status) {
      case QueueItemStatus.pending:
        return GestureDetector(
          onTap: () => ref.read(queueProvider.notifier).remove(item.id),
          child: const Icon(Icons.close, color: Color(0xFF5A5A6E), size: 20),
        );
      case QueueItemStatus.downloading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
        );
      case QueueItemStatus.done:
        return const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22);
      case QueueItemStatus.error:
        return GestureDetector(
          onTap: () => ref.read(queueProvider.notifier).retry(item.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Повторить',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
    }
  }

  Color _borderColor(QueueItemStatus status) {
    switch (status) {
      case QueueItemStatus.pending:
        return const Color(0xFF2A2A3A);
      case QueueItemStatus.downloading:
        return const Color(0xFF3B82F6).withValues(alpha: 0.5);
      case QueueItemStatus.done:
        return const Color(0xFF10B981).withValues(alpha: 0.4);
      case QueueItemStatus.error:
        return Colors.redAccent.withValues(alpha: 0.4);
    }
  }

  String _statusLabel(QueueItemStatus status) {
    switch (status) {
      case QueueItemStatus.pending:
        return '⏳ В очереди';
      case QueueItemStatus.downloading:
        return 'Загрузка...';
      case QueueItemStatus.done:
        return '✅ Готово';
      case QueueItemStatus.error:
        return '❌ Ошибка';
    }
  }

  Color _statusColor(QueueItemStatus status) {
    switch (status) {
      case QueueItemStatus.pending:
        return const Color(0xFF8A8A9E);
      case QueueItemStatus.downloading:
        return const Color(0xFF3B82F6);
      case QueueItemStatus.done:
        return const Color(0xFF10B981);
      case QueueItemStatus.error:
        return Colors.redAccent;
    }
  }
}
