import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_service.dart';
import 'notification_list_sheet.dart';

class AnimatedNotificationBell extends StatefulWidget {
  final Color iconColor;
  final Color badgeColor;
  final Color? backgroundColor;
  final double size;

  const AnimatedNotificationBell({
    super.key,
    this.iconColor = Colors.white,
    this.badgeColor = const Color(0xFFEF4444),
    this.backgroundColor,
    this.size = 24,
  });

  @override
  State<AnimatedNotificationBell> createState() => _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState extends State<AnimatedNotificationBell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Subtle vibration / wiggling animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Sequence of quick shakes followed by a brief pause
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.22).chain(CurveTween(curve: Curves.easeOut)), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.22, end: -0.22).chain(CurveTween(curve: Curves.easeInOut)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.22, end: 0.16).chain(CurveTween(curve: Curves.easeInOut)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.16, end: -0.12).chain(CurveTween(curve: Curves.easeInOut)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 30), // pause between shakes
    ]).animate(_controller);

    // Initial fetch of notifications
    NotificationService.instance.refreshUnreadCount();

    // Periodic check every 25 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted) {
        NotificationService.instance.refreshUnreadCount();
      }
    });

    // Listen to changes in unread count to start/stop shake animation
    NotificationService.unreadCountNotifier.addListener(_onUnreadCountChanged);

    if (NotificationService.unreadCountNotifier.value > 0) {
      _controller.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.refreshUnreadCount();
    }
  }

  void _onUnreadCountChanged() {
    if (!mounted) return;
    if (NotificationService.unreadCountNotifier.value > 0) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    NotificationService.unreadCountNotifier.removeListener(_onUnreadCountChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.unreadCountNotifier,
      builder: (context, unreadCount, _) {
        if (unreadCount > 0 && !_controller.isAnimating) {
          _controller.repeat();
        } else if (unreadCount == 0 && _controller.isAnimating) {
          _controller.stop();
          _controller.reset();
        }

        return InkWell(
          onTap: () async {
            await NotificationListSheet.show(context);
            if (mounted) {
              NotificationService.instance.refreshUnreadCount();
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: widget.backgroundColor != null
                ? BoxDecoration(
                    color: widget.backgroundColor,
                    shape: BoxShape.circle,
                  )
                : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Animated Shaking Bell
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animation.value,
                      alignment: const Alignment(0, -0.7), // pivot from top ring
                      child: child,
                    );
                  },
                  child: Icon(
                    unreadCount > 0
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_outlined,
                    color: widget.iconColor,
                    size: widget.size,
                  ),
                ),

                // Badge with Number
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: widget.badgeColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
