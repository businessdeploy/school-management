import 'package:flutter/material.dart';
import 'translated_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/app_config_provider.dart';
import 'package:provider/provider.dart';

class AppHeader extends StatefulWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onNotificationTap;
  final int unreadCount;

  const AppHeader({
    super.key,
    required this.onMenuTap,
    required this.onNotificationTap,
    this.unreadCount = 0,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onMenuTap,
            icon: const Icon(Icons.menu, color: Colors.black87, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          Expanded(
            child: Consumer<AppConfigProvider>(
              builder: (context, appConfigProvider, _) {
                final logoUrl = appConfigProvider.appLogo;
                final schoolName = appConfigProvider.schoolName.toUpperCase();
                final primaryColor = appConfigProvider.primaryColorObj;
                
                return Center(
                  child: logoUrl.isNotEmpty
                      ? Container(
                          constraints: const BoxConstraints(
                            maxWidth: 160,
                            maxHeight: 40,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: CachedNetworkImage(
                            imageUrl: logoUrl,
                            key: ValueKey(logoUrl),
                            fit: BoxFit.contain,
                            memCacheWidth: 300,
                            errorWidget: (context, url, error) {
                              return _buildFallbackBadge(schoolName, primaryColor);
                            },
                            placeholder: (context, url) => _buildLoadingIndicator(),
                          ),
                        )
                      : _buildFallbackBadge(schoolName, primaryColor),
                );
              },
            ),
          ),

          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: widget.onNotificationTap,
                icon: const Icon(
                  Icons.notifications,
                  color: Colors.black87,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (widget.unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBadge(String schoolName, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        schoolName.length > 11 ? schoolName.substring(0, 11) : schoolName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
