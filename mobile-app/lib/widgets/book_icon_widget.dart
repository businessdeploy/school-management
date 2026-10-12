import 'package:flutter/material.dart';

class BookIconWidget extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? bookColor;
  final Color? pagesColor;

  const BookIconWidget({
    super.key,
    this.size = 1024,
    this.backgroundColor,
    this.bookColor,
    this.pagesColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF1E3A8A),
        borderRadius: BorderRadius.circular(size * 0.1),
      ),
      child: Center(
        child: Container(
          width: size * 0.7,
          height: size * 0.8,
          decoration: BoxDecoration(
            color: bookColor ?? const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(size * 0.02),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: size * 0.01,
                offset: Offset(0, size * 0.005),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Book pages
              Positioned(
                top: size * 0.015,
                left: size * 0.015,
                right: size * 0.015,
                bottom: size * 0.015,
                child: Container(
                  decoration: BoxDecoration(
                    color: pagesColor ?? Colors.white,
                    borderRadius: BorderRadius.circular(size * 0.015),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.menu_book,
                      size: size * 0.25,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ),
              // Book spine
              Positioned(
                left: size * 0.01,
                top: size * 0.02,
                bottom: size * 0.02,
                child: Container(
                  width: size * 0.008,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(size * 0.004),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
