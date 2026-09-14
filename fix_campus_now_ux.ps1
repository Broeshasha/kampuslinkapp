$path = "C:\kampuslink\lib\features\home\home_screen.dart"
$raw = Get-Content $path -Raw
$content = $raw -replace "`r`n", "`n"

# --- 1. imports needed for the quick-post sheet's image upload ---
$old1 = "import '../profile/user_profile_screen.dart';"
$new1 = @'
import '../profile/user_profile_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/image_processing_service.dart';
import '../../core/config/upload_service.dart';
'@ -replace "`r`n", "`n"

if (-not $content.Contains($old1)) { Write-Host "ABORT: import anchor not found"; exit }
$content = $content.Replace($old1, $new1)

# --- 2. make the fullscreen viewer responsive on wide screens ---
$old2 = @'
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
'@ -replace "`r`n", "`n"

$new2 = @'
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SafeArea(
          child: Stack(
'@ -replace "`r`n", "`n"

if (-not $content.Contains($old2)) { Write-Host "ABORT: dialog-open anchor not found"; exit }
$content = $content.Replace($old2, $new2)

# --- 3. close the two new wrappers right after the existing SafeArea/Stack closes ---
$old3 = @'
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _rings.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _rings.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final ring = _rings[i];
'@ -replace "`r`n", "`n"

$new3 = @'
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openQuickPostSheet() async {
    final controller = TextEditingController();
    Uint8List? imageBytes;
    String? imageUrl;
    String? imageBlurhash;
    bool uploadingImage = false;
    bool posting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Post to Campus Now',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Visible to your campus for 24 hours',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "What's happening?",
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (imageBytes != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(imageBytes!,
                          height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                    if (uploadingImage)
                      const Positioned.fill(
                        child: Center(
                            child: CircularProgressIndicator(color: AppColors.accent)),
                      ),
                  ],
                )
              else
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked =
                        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
                    if (picked == null) return;

                    setModalState(() => uploadingImage = true);
                    final bytes = await picked.readAsBytes();
                    final processed =
                        ImageProcessingService.process(bytes, maxDimension: 1080);
                    setModalState(() => imageBytes = processed.imageBytes);

                    try {
                      final url = await UploadService.upload(
                        processed.imageBytes,
                        'community',
                        'post.jpg',
                      ).timeout(const Duration(seconds: 15));
                      setModalState(() {
                        imageUrl = url;
                        imageBlurhash = processed.blurhash;
                        uploadingImage = false;
                      });
                    } catch (e) {
                      debugPrint('Quick post image upload error: $e');
                      setModalState(() {
                        imageBytes = null;
                        uploadingImage = false;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined, size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Add a photo',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (posting || uploadingImage)
                    ? null
                    : () async {
                        final text = controller.text.trim();
                        if (text.isEmpty && imageUrl == null) return;

                        setModalState(() => posting = true);
                        final userId = _supabase.auth.currentUser!.id;

                        try {
                          await _supabase.from('community_posts').insert({
                            'user_id': userId,
                            'content': text,
                            'image_url': imageUrl,
                            'image_blurhash': imageBlurhash,
                            'is_campus_now': true,
                            'expires_at': DateTime.now()
                                .add(const Duration(hours: 24))
                                .toIso8601String(),
                          }).timeout(const Duration(seconds: 8));

                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          _load();
                        } catch (e) {
                          debugPrint('Quick post error: $e');
                          setModalState(() => posting = false);
                        }
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: posting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Post'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _rings.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            return GestureDetector(
              onTap: _openQuickPostSheet,
              child: SizedBox(
                width: 62,
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border, width: 1),
                        color: AppColors.surface,
                      ),
                      child: const Icon(Icons.add, color: AppColors.accent, size: 26),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Post',
                      maxLines: 1,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            );
          }

          final ring = _rings[i - 1];
'@ -replace "`r`n", "`n"

if (-not $content.Contains($old3)) { Write-Host "ABORT: closing/rebuild anchor not found"; exit }
$content = $content.Replace($old3, $new3)

$content = $content -replace "`n", "`r`n"
Set-Content -Path $path -Value $content -NoNewline
Write-Host "Campus Now: responsive viewer + quick-post added."