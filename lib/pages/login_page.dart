import 'package:flutter/material.dart';
import 'package:ciallo_reader/api/wenku_api.dart';
import '../models/login_status.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = '';

// 在 LoginPage 中


  // 在 lib/pages/login_page.dart 中

  void _doLogin() async {
    // 1. 检查输入是否为空
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _statusMessage = '账号和密码不能为空');
      return;
    }

    // 2. 显示加载状态
    setState(() {
      _isLoading = true;
      _statusMessage = '正在登录...';
    });

    // 3. 调用 API 获取结果 (类型是 LoginStatus)
    final status = await WenkuApi().login(
      _usernameController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    // 4. 关闭加载状态
    setState(() {
      _isLoading = false;
    });

    // 5. 【关键部分】使用 SwitchCase 处理结果
    switch (status) {
      case LoginStatus.success:
      // 登录成功，返回上一页
        Navigator.pop(context, true);
        break;

      case LoginStatus.passwordError:
        setState(() => _statusMessage = "密码错误，请检查输入");
        break;

      case LoginStatus.userNotFoundError:
        setState(() => _statusMessage = "该账号不存在");
        break;

      case LoginStatus.checkCodeError:
        setState(() => _statusMessage = "系统提示需要验证码，请稍后再试");
        break;

      case LoginStatus.unknownError:
        setState(() => _statusMessage = "登录失败，请检查网络连接");
        break;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录文库8')),
      body: Center(
        child: Container(
          width: 400, // 限制宽度，适应平板
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('账号登录', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: '用户名/账号', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              if (_statusMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_statusMessage, style: const TextStyle(color: Colors.red)),
                ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _doLogin,
                  child: _isLoading ? const CircularProgressIndicator() : const Text('登 录'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}