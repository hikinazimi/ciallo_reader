import 'package:flutter/material.dart';
import 'login_page.dart'; // 引入登录页

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("个人中心")),
      body: ListView(
        children: [
          const UserAccountsDrawerHeader(
            accountName: Text("未登录"),
            accountEmail: Text("点击下方按钮登录"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text("登录"),
            onTap: () async {
              // 跳转到登录页
              final success = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
              if (success == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("登录成功！")),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("设置"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text("关于 App"),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}