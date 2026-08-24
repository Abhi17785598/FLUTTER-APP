import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../providers/navigation_provider.dart';
import '../screens/reels/reels_screen.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const BottomNavBar({super.key, required this.currentIndex, this.onTap});

  // How far the "+" button visually floats above the nav bar center line.
  // Derived from the original design: a 56 dp button with a 20 dp bottom
  // margin centered inside a 64 dp row shifts the visual center from 32 to 22,
  // a 10 dp upward offset — preserved here via Transform.translate so no layout
  // overflow occurs.
  static const double _kButtonLift = 10.0;

  // Maximum width of the nav content before it stops growing. Prevents items
  // from becoming absurdly wide on tablets and large-screen foldables.
  static const double _kMaxContentWidth = 600.0;

  // Index of the Profile destination within this bar. Home 0, Search 1,
  // Reels 2, Profile 3 — the centre "+" occupies an unindexed slot.
  static const int _kProfileIndex = 3;

  void _defaultNavigation(BuildContext context, int index) {
    // Tapping Profile while already on Profile resets to the Profile root
    // rather than doing nothing, matching the prototype's `backToProfile`.
    //
    // The check reads the *route name* rather than `currentIndex` on purpose:
    // some screens pass a currentIndex that doesn't match the route they are
    // on, and keying off the route keeps this branch from firing on them.
    // Routes without forwarded RouteSettings report a null name, so they
    // simply fall through to the existing behaviour below.
    if (index == _kProfileIndex &&
        ModalRoute.of(context)?.settings.name == AppConstants.profileScreen) {
      // `route.isFirst` is a safety stop: if the Profile route were ever
      // reached without its settings, popUntil would otherwise unwind the
      // entire stack.
      Navigator.of(context).popUntil(
        (route) =>
            route.settings.name == AppConstants.profileScreen || route.isFirst,
      );
      return;
    }

    if (currentIndex == index) return;

    Provider.of<NavigationProvider>(context, listen: false).setIndex(index);

    if (index == 2) {
      // Reuse an existing ReelsScreen if one is already in the stack rather
      // than always pushing a new instance. Each ReelsScreen owns a
      // ReelControllerManager holding up to 3 live VideoPlayerControllers
      // (native video surfaces); pushing a fresh one every tap without ever
      // popping the old ones left prior instances buried (not disposed) in
      // the stack, accumulating undisposed native surfaces until the
      // Android surface buffer pool was exhausted (BLASTBufferQueue
      // "acquireNextBufferLocked: Can't acquire next buffer") and the
      // screen stopped rendering entirely.
      final navigator = Navigator.of(context);
      bool foundExisting = false;
      navigator.popUntil((route) {
        if (route.settings.name == AppConstants.reelsScreen) {
          foundExisting = true;
          return true;
        }
        return route.isFirst;
      });
      if (!foundExisting) {
        navigator.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: AppConstants.reelsScreen),
            builder: (context) => const ReelsScreen(),
          ),
        );
      }
      return;
    }

    String routeName;
    switch (index) {
      case 0:
        routeName = AppConstants.homeScreen;
        break;
      case 1:
        routeName = AppConstants.searchScreen;
        break;
      case 3:
        routeName = AppConstants.profileScreen;
        break;
      default:
        routeName = AppConstants.homeScreen;
    }

    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      final isRoot = ModalRoute.of(context)?.isFirst ?? true;
      if (isRoot) {
        Navigator.pushNamed(context, routeName);
      } else {
        Navigator.pushReplacementNamed(context, routeName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewPadding = mediaQuery.viewPadding;

    // This widget is a plain Container passed as Scaffold.bottomNavigationBar
    // — Scaffold does NOT automatically inset a custom bottomNavigationBar
    // above the system bottom area (that only happens for the body). So on
    // 3-button/button nav, where viewPadding.bottom is the real, non-zero
    // system nav bar height, that exact height must be used directly here;
    // assuming Scaffold already handled it (as the previous version did,
    // padding 0 in that case) left the bar unprotected on those devices.
    //
    // On Android 10+ gesture navigation, viewPadding.bottom is 0 (or very
    // small) because the system nav is transparent and gesture-based, so the
    // real danger zone is the gesture-capture strip instead, reported via
    // systemGestureInsets.bottom (commonly ~24-40 dp).
    final double bottomSafePadding = viewPadding.bottom > 0
        ? viewPadding.bottom
        : mediaQuery.systemGestureInsets.bottom.clamp(0.0, 40.0);

    return Container(
      // Total rendered height = visible content area + gesture-safe padding.
      // AppConstants.bottomNavHeight is the visual design height only.
      height: AppConstants.bottomNavHeight + bottomSafePadding,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.textHint, width: 0.5)),
      ),
      // Shift the content upward by the safe padding so the visible nav area
      // stays at AppConstants.bottomNavHeight and the padding appears below it
      // as an inert gap between the content and the screen edge.
      padding: EdgeInsets.only(bottom: bottomSafePadding),
      child: Center(
        child: ConstrainedBox(
          // On tablets and large-screen devices the Row would otherwise spread
          // items across the full width. This keeps them in a compact, usable
          // column centred on the screen — consistent with how Material
          // NavigationBar handles wide viewports.
          constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
          child: Row(
            // Expanded children replace spaceAround so each nav item gets
            // exactly 1/4 of the remaining width after the centre button slot
            // is allocated — not an estimate based on intrinsic content width.
            children: [
              Expanded(
                child: _buildNavItem(
                  context: context,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  index: 0,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  context: context,
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search,
                  label: 'Search',
                  index: 1,
                ),
              ),
              _buildPostPropertyButton(context),
              Expanded(
                child: _buildNavItem(
                  context: context,
                  icon: Icons.movie_outlined,
                  activeIcon: Icons.movie,
                  label: 'Reels',
                  index: 2,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  context: context,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  index: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostPropertyButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppConstants.postPropertyScreen);
      },
      // Explicit semantics so screen readers announce the action correctly even
      // though this button is not a standard nav item.
      child: Semantics(
        label: 'Post a property',
        button: true,
        child: SizedBox(
          // Fixed-width slot keeps the button the same size regardless of how
          // the surrounding Expanded items flex. 72 dp gives 8 dp clearance on
          // each side of the 56 dp button.
          width: 72,
          child: Center(
            child: Transform.translate(
              // Lift the button _kButtonLift dp above the nav bar centre line.
              // Transform.translate does not affect layout — the Row sees a
              // 56 dp child, so no overflow occurs. The button is painted above
              // its layout position into the body area (intentional floating
              // effect) without triggering Flutter's overflow error.
              offset: const Offset(0, -_kButtonLift),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.primaryGlow,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!(index);
        } else {
          _defaultNavigation(context, index);
        }
      },
      // opaque so the full Expanded area is tappable, not just the icon+label.
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: label,
        selected: isActive,
        button: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
