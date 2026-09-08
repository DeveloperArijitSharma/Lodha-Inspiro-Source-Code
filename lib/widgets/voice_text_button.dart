import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceTextButton extends StatefulWidget {
  final TextEditingController controller;
  final Color accentColor;
  final bool enabled;
  final String localeId;
  final String? tooltip;

  const VoiceTextButton({
    super.key,
    required this.controller,
    Color? accentColor,
    this.enabled = true,
    this.localeId = 'en_IN',
    Color? color,
    this.tooltip,
  }) : accentColor = color ?? accentColor ?? const Color(0xFF32C5FF);

  @override
  State<VoiceTextButton> createState() => _VoiceTextButtonState();
}

class _VoiceTextButtonState extends State<VoiceTextButton> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;
  String _baseText = '';

  Future<void> _toggle() async {
    if (!widget.enabled) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available) return;

    _baseText = widget.controller.text.trim();
    if (mounted) setState(() => _listening = true);

    await _speech.listen(
      localeId: widget.localeId,
      partialResults: true,
      onResult: (result) {
        final spoken = result.recognizedWords.trim();
        final joined = [_baseText, spoken].where((v) => v.isNotEmpty).join(' ');
        widget.controller.value = TextEditingValue(
          text: joined,
          selection: TextSelection.collapsed(offset: joined.length),
        );
        if (result.finalResult && mounted) setState(() => _listening = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip ?? (_listening ? 'Stop voice input' : 'Voice input'),
      onPressed: widget.enabled ? _toggle : null,
      icon: Icon(
        _listening ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
        color: _listening ? widget.accentColor : null,
      ),
      style: IconButton.styleFrom(
        backgroundColor: _listening ? widget.accentColor.withOpacity(.14) : null,
      ),
    );
  }
}
