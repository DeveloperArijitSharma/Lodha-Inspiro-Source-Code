import 'package:flutter/material.dart';
import '../widgets/voice_text_button.dart';

class VoiceAssistantField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final VoidCallback? onSend;
  final bool enabled;

  const VoiceAssistantField({
    super.key,
    required this.controller,
    this.hintText = 'Type or speak…',
    this.maxLines = 5,
    this.onSend,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            minLines: 1,
            maxLines: maxLines,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        VoiceTextButton(controller: controller),
        if (onSend != null)
          IconButton(
            tooltip: 'Send',
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send_rounded),
          ),
      ],
    );
  }
}
