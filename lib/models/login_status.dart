enum LoginStatus {
  success,          // 登录成功
  passwordError,    // 密码错误
  userNotFoundError,// 用户不存在
  checkCodeError,   // 验证码错误 (原代码中有相关判断)
  unknownError,     // 未知错误
}

extension LoginStatusExt on LoginStatus {
  String get message {
    switch (this) {
      case LoginStatus.success: return "登录成功";
      case LoginStatus.passwordError: return "密码错误";
      case LoginStatus.userNotFoundError: return "用户不存在";
      case LoginStatus.checkCodeError: return "验证码错误"; // 对应原代码 isCheckcodeCorrect = false
      case LoginStatus.unknownError: return "未知错误";
    }
  }
}