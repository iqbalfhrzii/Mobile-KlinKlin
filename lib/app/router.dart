import 'package:go_router/go_router.dart';
import '../features/home/screens/home_screen.dart';

/// Semua route app Klinklin didefinisikan di sini.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    // TODO: Tambahkan route lain di sini
    // GoRoute(
    //   path: '/orders',
    //   name: 'orders',
    //   builder: (context, state) => const OrdersScreen(),
    //   routes: [
    //     GoRoute(
    //       path: ':id',
    //       name: 'order-detail',
    //       builder: (context, state) {
    //         final id = state.pathParameters['id']!;
    //         return OrderDetailScreen(orderId: id);
    //       },
    //     ),
    //   ],
    // ),
  ],
);
