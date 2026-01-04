# 📚 Ciallore (轻小说阅读器)

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.0%2B-blue?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.0%2B-blue?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

一个基于 Flutter (Dart) 实现的简洁本地轻小说阅读器，支持 Android手机/平板端。

> ⚠️ **免责声明**：本项目仅供技术学习与交流使用，所有小说数据及图片版权归Wenku8 网站所有。请勿用于商业用途。

## ✨ 功能特性 (Features)

- **🔍 搜索功能**
  - 支持按 **小说标题** 和 **作者名称** 搜索。
  - 解决 GBK 编码问题，支持中文关键词搜索。
  - 支持下拉加载。

- **🖼️ 图片加载优化**
  - 集成 **CachedNetworkImage**，实现图片本地缓存，节省流量。
  - 统一的图片组件封装，支持加载动画与错误占位。

- **📖 核心阅读体验**
  - 解析 Wenku8 网页结构，提取小说详情、简介、Tags。
  - (正在开发中) 章节阅读与书架管理。

## 🛠️ 技术栈 (Tech Stack)

* **框架**: [Flutter](https://flutter.dev/)
* **网络请求**: [Dio](https://pub.dev/packages/dio) (配合 CookieJar 持久化)
* **HTML 解析**: [html](https://pub.dev/packages/html) (自定义 Parser 解析器)
* **图片缓存**: [cached_network_image](https://pub.dev/packages/cached_network_image)
* **编码工具**: [fast_gbk](https://pub.dev/packages/fast_gbk) (解决老旧网站编码问题)
* **本地存储**: [Hive](https://pub.dev/packages/hive) (用于书架数据持久化)

## 📸 预览 (Screenshots)




