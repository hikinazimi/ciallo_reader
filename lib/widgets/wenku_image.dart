import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class WenkuImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius; // 支持圓角設置

  const WenkuImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 4.0, // 默認圓角 4
  });

  @override
  Widget build(BuildContext context) {
    // 如果 URL 為空，直接顯示錯誤佔位圖
    if (url.isEmpty) return _buildError();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,

        // 🔥🔥🔥 核心：統一配置防盜鏈 Header
        // 只要用了這個組件，圖片都能下載成功並緩存到本地
        httpHeaders: const {
          "Referer": "https://www.wenku8.net/",
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        },

        // 1. 加載中動畫
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)
              )
          ),
        ),

        // 2. 加載失敗佔位圖
        errorWidget: (context, url, error) => _buildError(),

        // 3. 淡入效果
        fadeInDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      alignment: Alignment.center,
      // 1. 去掉这里的 const
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 2. 将 const 加到具体的静态组件上
          const Icon(Icons.broken_image, color: Colors.grey, size: 20),

          if ((height ?? 100) > 60) ...[
            const SizedBox(height: 2),
            const Text("暫無", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ]
        ],
      ),
    );
  }
}