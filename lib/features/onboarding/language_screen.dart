import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kampus_mark.dart';

class LanguageScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const LanguageScreen({super.key, required this.onContinue});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  int _selected = 0;
  final _languages = const [
    ('EN', 'English'),
    ('FR', 'Français'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const KampusMark(size: 28, color: AppColors.accent),
              const SizedBox(height: 12),
              const Text('KampusLink',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 48),
              const Text('Choose your language',
                  style: TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              ...List.generate(_languages.length, (i) {
                final selected = _selected == i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? AppColors.accent : AppColors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? AppColors.accent : AppColors.background,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _languages[i].$1,
                              style: TextStyle(
                                color: selected ? Colors.white : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(_languages[i].$2,
                              style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: widget.onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
