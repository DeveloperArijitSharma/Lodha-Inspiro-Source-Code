import 'package:flutter/material.dart';
import '../widgets/voice_text_button.dart';

class VoiceAssistantField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final VoidCallback? onSend;

  const VoiceAssistantField({super.key, required this.controller, this.hintText = 'Type or speak…', this.maxLines = 5, this.onSend});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: TextField(controller: controller, minLines: 1, maxLines: maxLines, decoration: InputDecoration(hintText: hintText, border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)))),),
      const SizedBox(width: 6),
      VoiceTextButton(controller: controller),
      if (onSend != null) IconButton(onPressed: onSend, icon: const Icon(Icons.send_rounded)),
    ]);
  }
}
