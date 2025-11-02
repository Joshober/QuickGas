import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final String userRole; // 'customer' or 'driver'

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.userRole,
  });

  List<BottomNavigationBarItem> _getItems() {
    if (userRole == AppConstants.roleDriver) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.route_outlined),
          activeIcon: Icon(Icons.route),
          label: 'Routes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_shipping_outlined),
          activeIcon: Icon(Icons.local_shipping),
          label: 'Deliveries',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    } else {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart_outlined),
          activeIcon: Icon(Icons.shopping_cart),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on_outlined),
          activeIcon: Icon(Icons.location_on),
          label: 'Tracking',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    }
  }

  void _onTap(BuildContext context, int index) {
    if (userRole == AppConstants.roleDriver) {
      switch (index) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/driver/routes');
          break;
        case 2:
          context.go('/driver/deliveries');
          break;
        case 3:
          context.go('/driver/profile');
          break;
      }
    } else {
      switch (index) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/customer/orders');
          break;
        case 2:
          context.go('/customer/tracking');
          break;
        case 3:
          context.go('/customer/profile');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onTap(context, index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: Colors.grey,
      elevation: 8,
      items: _getItems(),
    );
  }
}
