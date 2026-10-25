import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LogPanel extends StatelessWidget {
  const LogPanel({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140, maxHeight: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF071014),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: lines.isEmpty
          ? const Text(
              'Activity log will appear here…',
              style: TextStyle(
                color: AppTheme.muted,
                fontFamily: 'Consolas',
                fontSize: 13,
              ),
            )
          : ListView.builder(
              itemCount: lines.length,
              itemBuilder: (context, i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    lines[i],
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontFamily: 'Consolas',
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
