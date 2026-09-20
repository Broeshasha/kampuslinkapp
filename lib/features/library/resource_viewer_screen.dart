import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';

class ResourceViewerScreen extends StatefulWidget {
  final String title;
  final String fileFormat;
  final List<String> fileUrls;

  const ResourceViewerScreen({
    super.key,
    required this.title,
    required this.fileFormat,
    required this.fileUrls,
  });

  @override
  State<ResourceViewerScreen> createState() => _ResourceViewerScreenState();
}

class _ResourceViewerScreenState extends State<ResourceViewerScreen> {
  PdfControllerPinch? _pdfController;
  bool _loading = true;
  String? _error;
  int _currentImagePage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.fileFormat == 'pdf') {
      _loadPdf();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadPdf() async {
    if (widget.fileUrls.isEmpty) {
      setState(() {
        _error = 'No file to display.';
        _loading = false;
      });
      return;
    }
    try {
      final resp = await http
          .get(Uri.parse(widget.fileUrls.first))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        throw Exception('Server returned ${resp.statusCode}');
      }
      final Uint8List bytes = resp.bodyBytes;
      final controller = PdfControllerPinch(
        document: PdfDocument.openData(bytes),
      );
      if (!mounted) return;
      setState(() {
        _pdfController = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this document. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.surface,
        actions: widget.fileFormat == 'image_set' && widget.fileUrls.length > 1
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      '${_currentImagePage + 1} / ${widget.fileUrls.length}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.textSecondary, size: 40),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _loadPdf();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.fileFormat == 'pdf' && _pdfController != null) {
      return PdfViewPinch(controller: _pdfController!);
    }

    if (widget.fileFormat == 'image_set') {
      return PhotoViewGallery.builder(
        itemCount: widget.fileUrls.length,
        onPageChanged: (i) => setState(() => _currentImagePage = i),
        builder: (context, i) => PhotoViewGalleryPageOptions(
          imageProvider: CachedNetworkImageProvider(widget.fileUrls[i]),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
        ),
        loadingBuilder: (context, event) =>
            const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      );
    }

    return const Center(
      child: Text('Unsupported file type.', style: TextStyle(color: AppColors.textSecondary)),
    );
  }
}