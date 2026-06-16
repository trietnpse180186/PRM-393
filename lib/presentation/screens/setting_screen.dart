import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SettingScreen extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String initialPhone;

  const SettingScreen({
    super.key,
    required this.initialName,
    required this.initialEmail,
    required this.initialPhone,
  });

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  bool _notifyLessons = true;
  bool _notifyUpdates = true;
  bool _twoFactorEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSavePressed() {
    if (_formKey.currentState?.validate() ?? false) {
      // Show saving spinner snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
              ),
              SizedBox(width: 12),
              Text('Đang lưu thay đổi...'),
            ],
          ),
          backgroundColor: AppTheme.surfaceContainer,
        ),
      );

      // Simulate API call
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu cài đặt tài khoản thành công!'),
            backgroundColor: AppTheme.primaryContainer,
          ),
        );
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Cài đặt tài khoản',
          style: textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
              child: const Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 18),
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
      body: Stack(
        children: [
          Container(color: AppTheme.backgroundColor),
          SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section: Thông tin cá nhân
                      _buildSectionHeader(Icons.person_outline_rounded, 'Thông tin cá nhân', textTheme),
                      const SizedBox(height: 12),
                      AppTheme.glassPanel(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              label: 'Họ và tên',
                              hint: 'Nhập họ và tên',
                              validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'example@email.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập email';
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val.trim())) return 'Email không hợp lệ';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Số điện thoại',
                              hint: 'Nhập số điện thoại',
                              keyboardType: TextInputType.phone,
                              validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập số điện thoại' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Section: Bảo mật
                      _buildSectionHeader(Icons.shield_outlined, 'Bảo mật', textTheme),
                      const SizedBox(height: 12),
                      AppTheme.glassPanel(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.lock_reset_rounded, color: AppTheme.onSurfaceVariant, size: 20),
                              title: const Text('Đổi mật khẩu', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceVariant, size: 20),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Tính năng đổi mật khẩu đang được xử lý.'),
                                    backgroundColor: AppTheme.surfaceContainer,
                                  ),
                                );
                              },
                            ),
                            Divider(color: Colors.white.withOpacity(0.05), height: 1),
                            SwitchListTile(
                              secondary: const Icon(Icons.verified_user_rounded, color: AppTheme.onSurfaceVariant, size: 20),
                              title: const Text('Xác thực 2 yếu tố', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                _twoFactorEnabled ? 'Đang kích hoạt' : 'Chưa kích hoạt',
                                style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                              ),
                              value: _twoFactorEnabled,
                              activeColor: AppTheme.primaryColor,
                              activeTrackColor: AppTheme.primaryContainer.withOpacity(0.5),
                              inactiveThumbColor: AppTheme.onSurfaceVariant,
                              inactiveTrackColor: Colors.white10,
                              onChanged: (val) {
                                setState(() {
                                  _twoFactorEnabled = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Section: Thông báo
                      _buildSectionHeader(Icons.notifications_none_rounded, 'Thông báo', textTheme),
                      const SizedBox(height: 12),
                      AppTheme.glassPanel(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            _buildToggleRow(
                              title: 'Thông báo bài học',
                              subtitle: 'Nhắc nhở học tập hàng ngày',
                              value: _notifyLessons,
                              onChanged: (val) {
                                setState(() {
                                  _notifyLessons = val;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildToggleRow(
                              title: 'Cập nhật ứng dụng',
                              subtitle: 'Thông tin về tính năng mới',
                              value: _notifyUpdates,
                              onChanged: (val) {
                                setState(() {
                                  _notifyUpdates = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Action Button
                      ElevatedButton(
                        onPressed: _onSavePressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: AppTheme.onPrimaryContainer,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: Text(
                          'Lưu thay đổi',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onPrimaryContainer,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, TextTheme textTheme) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.secondaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: AppTheme.primaryColor,
          activeTrackColor: AppTheme.primaryContainer.withOpacity(0.5),
          inactiveThumbColor: AppTheme.onSurfaceVariant,
          inactiveTrackColor: Colors.white10,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
