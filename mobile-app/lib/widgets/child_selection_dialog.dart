import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../providers/app_config_provider.dart';
import 'package:provider/provider.dart';

class ChildSelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final Function(Map<String, dynamic>) onChildSelected;

  const ChildSelectionDialog({
    super.key,
    required this.children,
    required this.onChildSelected,
  });

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfigProvider.primaryColorObj;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Child List',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: children.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withOpacity(0.1),
                    ),
                    child: child['image'] != null && child['image'].toString().isNotEmpty
                        ? ClipOval(
                            child: FutureBuilder<String>(
                              future: ApiService.getImageUrl(child['image'].toString()),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return CachedNetworkImage(
                                    imageUrl: snapshot.data!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                    errorWidget: (context, url, error) => Icon(Icons.person, color: primaryColor),
                                  );
                                }
                                return const CircularProgressIndicator(strokeWidth: 2);
                              },
                            ),
                          )
                        : Icon(Icons.person, color: primaryColor),
                  ),
                  title: Text(
                    child['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${child['class']} - ${child['section']}'),
                  onTap: () => onChildSelected(child),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
