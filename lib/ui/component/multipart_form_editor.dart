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
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/utils/multipart.dart';

/// multipart/form-data 表单中的一行：参数名 + 参数值，或者参数名 + 文件。
class MultipartFormField {
  final TextEditingController name;
  final TextEditingController value;

  /// 选中的本地文件路径；Android SAF 等拿不到路径时用 [fileData]。
  String? filePath;

  /// 文件名（不含路径）
  String? fileName;

  /// 文件字节（无路径平台使用）
  List<int>? fileData;

  /// 文件大小，仅用于展示
  int fileSize = 0;

  MultipartFormField({String name = '', String value = ''})
      : name = TextEditingController(text: name),
        value = TextEditingController(text: value);

  bool get hasFile => fileData != null || (filePath != null && filePath!.isNotEmpty);

  void clearFile() {
    filePath = null;
    fileName = null;
    fileData = null;
    fileSize = 0;
  }

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

/// multipart/form-data 表单编辑器。
/// 每行可以是「参数名=参数值」的文本 part，也可以是「参数名=@文件」的文件 part（等价于 curl 的 -F）。
class MultipartFormEditor extends StatefulWidget {
  /// 当前使用的 boundary，用于在界面上提示自动设置的 Content-Type。
  final String boundary;
  final EdgeInsetsGeometry? padding;

  const MultipartFormEditor({super.key, required this.boundary, this.padding});

  @override
  State<MultipartFormEditor> createState() => MultipartFormEditorState();
}

class MultipartFormEditorState extends State<MultipartFormEditor> {
  final List<MultipartFormField> fields = [MultipartFormField()];

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  /// 收集所有参数名非空的行，用于构造请求体。
  List<MultipartPart> toParts() {
    return fields
        .where((field) => field.name.text.isNotEmpty)
        .map((field) => MultipartPart(
              name: field.name.text,
              value: field.value.text,
              filePath: field.filePath,
              fileName: field.fileName,
              data: field.fileData,
            ))
        .toList();
  }

  void _addField() {
    setState(() => fields.add(MultipartFormField()));
  }

  void _removeField(int index) {
    setState(() {
      fields.removeAt(index).dispose();
      if (fields.isEmpty) fields.add(MultipartFormField());
    });
  }

  /// 选择待上传文件；支持多选，第一个填入当前行，其余自动新增行并沿用同一参数名。
  Future<void> _pickFiles(int index) async {
    // pickFiles 默认允许多选（等价于多个 curl -F）
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty || !mounted) return;

    final name = fields[index].name.text;
    final loaded = <_PickedFile>[];
    for (final file in result.files) {
      final path = file.path;
      if (path != null && path.isNotEmpty) {
        loaded.add(_PickedFile(path: path, fileName: file.name, size: file.size));
        continue;
      }
      try {
        final bytes = await file.readAsBytes();
        loaded.add(_PickedFile(data: bytes, fileName: file.name, size: bytes.length));
      } catch (_) {
        // 无法读取的文件（如部分 SAF 场景）直接跳过
      }
    }
    if (!mounted) return;
    if (loaded.isEmpty) {
      FlutterToastr.show(localizations.fail, context);
      return;
    }

    setState(() {
      for (var i = 0; i < loaded.length; i++) {
        final picked = loaded[i];
        // 多选时：第一个文件填入当前行，其余沿用同一参数名追加新行
        if (i > 0) fields.add(MultipartFormField(name: name));
        final field = fields[i == 0 ? index : fields.length - 1];
        field.filePath = picked.path;
        field.fileName = picked.fileName;
        field.fileData = picked.data;
        field.fileSize = picked.size;
      }
    });
  }

  void _clearFile(int index) {
    setState(() => fields[index].clearFile());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: widget.padding ?? const EdgeInsets.only(right: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline, size: 14, color: theme.hintColor),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              MultipartFormBuilder.contentType(widget.boundary),
              style: TextStyle(fontSize: 12, color: theme.hintColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        for (var i = 0; i < fields.length; i++) _row(i),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addField,
            icon: const Icon(Icons.add, size: 16),
            label: Text(localizations.add, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ]),
    );
  }

  Widget _row(int index) {
    final field = fields[index];
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: _input(controller: field.name, hint: localizations.name),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 6,
          child: field.hasFile
              ? _fileTile(index, field)
              : _input(controller: field.value, hint: localizations.value),
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: localizations.selectFile,
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.upload_file_outlined, color: field.hasFile ? theme.colorScheme.primary : null),
          onPressed: () => _pickFiles(index),
        ),
        IconButton(
          tooltip: localizations.delete,
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => _removeField(index),
        ),
      ]),
    );
  }

  Widget _input({required TextEditingController controller, required String hint}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      minLines: 1,
      maxLines: 3,
      onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        isDense: true,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12.5),
        contentPadding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        focusedBorder:
            OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.2)),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.black12)),
        border: const OutlineInputBorder(),
        hintText: hint,
      ),
    );
  }

  /// 已选择文件的展示：文件名 + 大小 + 清除按钮
  Widget _fileTile(int index, MultipartFormField field) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        Icon(Icons.insert_drive_file_outlined, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${field.fileName ?? field.filePath}  (${_formatSize(field.fileSize)})',
            style: const TextStyle(fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        InkWell(
          onTap: () => _clearFile(index),
          child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.close, size: 14)),
        ),
      ]),
    );
  }

  static String _formatSize(int size) {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / 1024 / 1024).toStringAsFixed(2)}MB';
  }
}

class _PickedFile {
  final String? path;
  final List<int>? data;
  final String fileName;
  final int size;

  const _PickedFile({this.path, this.data, required this.fileName, required this.size});
}
