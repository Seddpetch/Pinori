import 'package:flutter/material.dart';
import '../../../core/theme/pinori_colours.dart';

enum PinoriPanel { none, places, add, trips }

class PinoriNavBar extends StatelessWidget {
  final PinoriPanel activePanel;
  final ValueChanged<PinoriPanel> onSelected;

  const PinoriNavBar({
    super.key,
    required this.activePanel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: PinoriColours.ivoryMist,
                border: Border.all(color: PinoriColours.richMahogany, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavIcon(
                    icon: Icons.format_list_bulleted,
                    selected: activePanel == PinoriPanel.places,
                    onTap: () => onSelected(PinoriPanel.places),
                  ),

                  const SizedBox(width: 60),

                  _NavIcon(
                    icon: Icons.work_outline,
                    selected: activePanel == PinoriPanel.trips,
                    onTap: () => onSelected(PinoriPanel.trips),
                  ),
                ],
              ),
            ),

            Positioned(
              top: -4,
              child: GestureDetector(
                onTap: () => onSelected(PinoriPanel.add),
                child: AnimatedScale(
                  scale: activePanel == PinoriPanel.add ? 1.08 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PinoriColours.tomatoJam,
                      border: Border.all(
                        color: PinoriColours.richMahogany,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      size: 50,
                      color: PinoriColours.ivoryMist,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Icon(
          icon,
          size: 32,
          color: selected
              ? PinoriColours.tomatoJam
              : PinoriColours.richMahogany,
        ),
      ),
    );
  }
}
