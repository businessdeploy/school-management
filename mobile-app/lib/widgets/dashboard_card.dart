import 'package:flutter/material.dart';
import '../providers/app_config_provider.dart';
import 'package:provider/provider.dart';
import 'translated_text.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final List<DashboardItem> items;
  final Color? backgroundColor;

  const DashboardCard({
    super.key,
    required this.title,
    required this.items,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TranslatedText(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          // 4-Column Grid
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 0,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item.isPlaceholder) {
                  return const SizedBox.shrink();
                }
                return _buildModuleCard(item, context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(DashboardItem item, BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfigProvider.primaryColorObj;

    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon area
          SizedBox(
            height: 36,
            width: 36,
            child: item.imagePath != null
                ? Image.asset(
                    item.imagePath!,
                    width: item.imageSize ?? 28,
                    height: item.imageSize ?? 28,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        item.icon ?? Icons.apps,
                        color: Colors.grey[600],
                        size: 24,
                      );
                    },
                  )
                : Icon(
                    item.icon ?? Icons.apps,
                    color: item.iconColor ?? Colors.grey[600],
                    size: 24,
                  ),
          ),
          const SizedBox(height: 4),
          // Module Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              height: 32, // Fixed height for 2 lines of text to ensure alignment
              child: Center(
                child: TranslatedText(
                  item.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                    height: 1.1,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class DashboardItem {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? imagePath;
  final double? imageSize; // New property for custom size
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool isPlaceholder;

  DashboardItem({
    required this.title,
    this.subtitle,
    this.icon,
    this.imagePath,
    this.imageSize,
    this.iconColor,
    this.onTap,
    this.isPlaceholder = false,
  });
}
