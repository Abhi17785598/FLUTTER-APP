import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class SearchBarWidget extends StatelessWidget {
  final String hint;
  final VoidCallback? onTap;
  final Widget? trailing;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  const SearchBarWidget({
    super.key,
    required this.hint,
    this.onTap,
    this.trailing,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isReadOnly = onTap != null;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),

          const Icon(
            Icons.search,
            color: AppColors.textSecondary,
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: isReadOnly
                ? GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hint,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  )
                : TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    textInputAction: TextInputAction.search,
                    autofocus: autofocus,
                    style: AppTextStyles.body.copyWith(
                      height: 1.2,
                    ),
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: AppTextStyles.body.copyWith(
                        color: AppColors.textHint,
                        height: 1.2,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.only(
                        bottom: 12,
                      ),
                    ),
                  ),
          ),

          if (!isReadOnly &&
              controller != null &&
              controller!.text.isNotEmpty) ...[
            IconButton(
              icon: const Icon(
                Icons.clear,
                color: AppColors.textSecondary,
                size: 18,
              ),
              onPressed: onClear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],

          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}