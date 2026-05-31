import 'package:flutter/material.dart';

class HorizontalBadgeList extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final List<String> items;
  final VoidCallback? onShowMore;
  final Function(String)? onItemTap;

  const HorizontalBadgeList({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.items,
    this.onShowMore,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            color: color.withOpacity(0.85),
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...items.map((item) => GestureDetector(
                  onTap: () => onItemTap?.call(item),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.35)),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}