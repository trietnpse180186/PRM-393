import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/usecases/learning/fetch_notifications_usecase.dart';
import '../../domain/usecases/learning/mark_notification_as_read_usecase.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;
  int _userId = 3; // Default test user

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _userId = authState.user.id;
      }
      _fetchNotifications();
    });
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fetchUseCase = context.read<FetchNotificationsUseCase>();
      final list = await fetchUseCase(_userId);
      
      if (mounted) {
        setState(() {
          _notifications = list.map((item) => Map<String, dynamic>.from(item)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(int notificationId, int index) async {
    try {
      final markUseCase = context.read<MarkNotificationAsReadUseCase>();
      await markUseCase(notificationId);
      
      if (mounted) {
        setState(() {
          _notifications[index]['isRead'] = true;
          _notifications[index]['isUnread'] = false; // Compatibility
        });
      }
    } catch (e) {
      print("Lỗi đánh dấu đã đọc thông báo: $e");
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Vừa xong';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Vừa xong';
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return '${diff.inHours} giờ trước';
      if (diff.inDays < 7) {
        final days = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
        return days[date.weekday % 7];
      }
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return 'Vừa xong';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Filter today vs older notifications
    final todayNotifications = <Map<String, dynamic>>[];
    final olderNotifications = <Map<String, dynamic>>[];

    final now = DateTime.now();
    for (final item in _notifications) {
      try {
        final date = DateTime.parse(item['createdAt'] ?? item['created_at'] ?? '').toLocal();
        final diff = now.difference(date);
        if (diff.inDays == 0 && date.day == now.day) {
          todayNotifications.add(item);
        } else {
          olderNotifications.add(item);
        }
      } catch (_) {
        todayNotifications.add(item);
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Thông báo',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_notifications.any((n) => !(n['isRead'] ?? false)))
            TextButton(
              onPressed: () async {
                // Mark all as read
                for (int i = 0; i < _notifications.length; i++) {
                  if (!(_notifications[i]['isRead'] ?? false)) {
                    await _markAsRead(_notifications[i]['id'] as int, i);
                  }
                }
              },
              child: const Text(
                'Đọc tất cả',
                style: TextStyle(color: AppTheme.primaryColor, fontSize: 13),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white.withOpacity(0.05),
            height: 1.0,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.surfaceContainer,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(
                        child: Text(
                          'Lỗi tải thông báo: $_error',
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : _notifications.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          const Center(
                            child: Column(
                              children: [
                                Icon(Icons.notifications_off_rounded, color: AppTheme.onSurfaceVariant, size: 48),
                                SizedBox(height: 16),
                                Text(
                                  'Bạn chưa có thông báo nào.',
                                  style: TextStyle(color: AppTheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          if (todayNotifications.isNotEmpty) ...[
                            _buildSectionHeader('HÔM NAY', textTheme),
                            const SizedBox(height: 12),
                            ...List.generate(todayNotifications.length, (index) {
                              final item = todayNotifications[index];
                              final globalIndex = _notifications.indexOf(item);
                              return _buildNotificationCard(item, globalIndex, textTheme);
                            }),
                            const SizedBox(height: 24),
                          ],
                          if (olderNotifications.isNotEmpty) ...[
                            _buildSectionHeader('CŨ HƠN', textTheme),
                            const SizedBox(height: 12),
                            ...List.generate(olderNotifications.length, (index) {
                              final item = olderNotifications[index];
                              final globalIndex = _notifications.indexOf(item);
                              return _buildNotificationCard(item, globalIndex, textTheme);
                            }),
                          ],
                        ],
                      ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, TextTheme textTheme) {
    return Text(
      title,
      style: textTheme.labelLarge?.copyWith(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        fontSize: 11,
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item, int index, TextTheme textTheme) {
    final isUnread = !(item['isRead'] ?? false);
    final iconData = isUnread ? Icons.mark_email_unread_rounded : Icons.mark_email_read_rounded;
    final iconColor = isUnread ? AppTheme.secondaryColor : AppTheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: isUnread ? Colors.white.withOpacity(0.04) : Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isUnread ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.02),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withOpacity(0.1),
          ),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Text(
          item['title'] ?? 'Thông báo',
          style: TextStyle(
            color: isUnread ? Colors.white : Colors.white70,
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item['body'] ?? '',
              style: TextStyle(
                color: isUnread ? Colors.white70 : AppTheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatTime(item['createdAt'] ?? item['created_at']),
              style: const TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
        onTap: () {
          if (isUnread) {
            _markAsRead(item['id'] as int, index);
          }
        },
      ),
    );
  }
}
