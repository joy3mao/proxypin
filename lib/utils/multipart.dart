/*
 * Copyright 2023 Hongen Wang All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// multipart/form-data 表单中的一个 part（等价于 curl 的一个 -F 参数）。
/// - [filePath] / [data] 任一非空表示这是一个文件 part，会带上 filename；
/// - 否则按普通文本 part 处理，发送 [value]。
class MultipartPart {
  String name;
  String value;

  /// 本地文件路径；Android SAF 等拿不到路径的场景用 [data] 代替。
  String? filePath;

  /// 文件名（不含路径）。为空时从 [filePath] 推导。
  String? fileName;

  /// 文件内容；[filePath] 为空时直接使用。
  List<int>? data;

  MultipartPart({this.name = '', this.value = '', this.filePath, this.fileName, this.data});

  bool get isFile => data != null || (filePath != null && filePath!.isNotEmpty);

  /// 推导出的文件名
  String get resolvedFileName {
    if (fileName != null && fileName!.isNotEmpty) return fileName!;
    final path = filePath;
    if (path == null || path.isEmpty) return 'file';
    return path.split(RegExp(r'[/\\]')).last;
  }
}

/// multipart/form-data 请求体构造器。
class MultipartFormBuilder {
  static const String _boundaryPrefix = '----ProxyPinBoundary';
  static const String _chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final Random _random = Random();

  /// 常见扩展名对应的 MIME；未命中时用 [defaultMime]。
  static const Map<String, String> _mimeTypes = {
    'txt': 'text/plain',
    'md': 'text/markdown',
    'csv': 'text/csv',
    'json': 'application/json',
    'xml': 'application/xml',
    'html': 'text/html',
    'htm': 'text/html',
    'css': 'text/css',
    'js': 'text/javascript',
    'pdf': 'application/pdf',
    'zip': 'application/zip',
    'gz': 'application/gzip',
    'tar': 'application/x-tar',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'bmp': 'image/bmp',
    'ico': 'image/x-icon',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'bin': 'application/octet-stream',
  };

  static const String defaultMime = 'application/octet-stream';

  /// 生成随机 boundary，形如 `----ProxyPinBoundaryA1b2C3d4E5f6G7h8`。
  static String generateBoundary() {
    final buffer = StringBuffer(_boundaryPrefix);
    for (int i = 0; i < 16; i++) {
      buffer.write(_chars[_random.nextInt(_chars.length)]);
    }
    return buffer.toString();
  }

  /// 带 boundary 的 Content-Type 值。
  static String contentType(String boundary) => 'multipart/form-data; boundary=$boundary';

  /// 按文件名后缀推断 MIME。
  static String mimeType(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index < 0 || index == fileName.length - 1) return defaultMime;
    return _mimeTypes[fileName.substring(index + 1).toLowerCase()] ?? defaultMime;
  }

  /// 构造 multipart/form-data 请求体字节。
  /// 参数名为空的 part 会被忽略；文件读取失败会抛出异常，由调用方处理。
  static Future<Uint8List> build(String boundary, List<MultipartPart> parts) async {
    final builder = BytesBuilder(copy: false);
    for (final part in parts) {
      if (part.name.isEmpty) continue;

      builder.add(utf8.encode('--$boundary\r\n'));
      if (part.isFile) {
        final fileName = part.resolvedFileName;
        builder.add(utf8.encode(
            'Content-Disposition: form-data; name="${part.name}"; filename="$fileName"\r\n'));
        builder.add(utf8.encode('Content-Type: ${mimeType(fileName)}\r\n\r\n'));
        builder.add(part.data ?? await File(part.filePath!).readAsBytes());
        builder.add(utf8.encode('\r\n'));
      } else {
        builder.add(utf8.encode('Content-Disposition: form-data; name="${part.name}"\r\n\r\n'));
        builder.add(utf8.encode(part.value));
        builder.add(utf8.encode('\r\n'));
      }
    }

    builder.add(utf8.encode('--$boundary--\r\n'));
    return builder.toBytes();
  }
}
