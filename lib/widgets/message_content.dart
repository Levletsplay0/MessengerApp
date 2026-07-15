import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';

class MessageContent extends StatelessWidget {
  final String content;
  final bool isOwn;

  const MessageContent({
    super.key,
    required this.content,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MarkdownBody(
      data: content,
      selectable: true,
      
      styleSheet: MarkdownStyleSheet(
        tableColumnWidth: FixedColumnWidth(150.0),
        p: const TextStyle(fontSize: 15, height: 1.35),
        code: TextStyle(
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
          color: isDark ? Colors.orange[200] : Colors.red[700],
          fontFamily: 'RobotoMono',
          fontSize: 14,
        ),
        codeblockDecoration: const BoxDecoration(),
        blockquoteDecoration: BoxDecoration(
          color: isDark
              ? Colors.blue[900]!.withValues(alpha: 0.2)
              : Colors.blue[50],
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
        ),
      ),
      builders: {
        'code': CodeElementBuilder(isDark: isDark),
      },
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final bool isDark;

  CodeElementBuilder({required this.isDark});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var language = '';

    if (element.attributes['class'] != null) {
      String lang = element.attributes['class'] as String;
      if (lang.startsWith('language-')) {
        language = lang.substring(9);
      }
    }

    final codeText = element.textContent;
    final isBlock = codeText.contains('\n') || language.isNotEmpty;

    if (isBlock) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 350),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (language.isNotEmpty && language != 'plaintext')
                    Text(
                      language,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                    ),
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: codeText.trim()));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
              child: HorizontalCodeScroll(
                isDark: isDark,
                child: HighlightView(
                  codeText.trim(),
                  language: language.isEmpty ? 'plaintext' : language,
                  theme: isDark ? atomOneDarkTheme : githubTheme,
                  textStyle: const TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          codeText,
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 13,
            color: isDark ? Colors.orange[200] : Colors.red[700],
          ),
        ),
      );
    }
  }
}

class HorizontalCodeScroll extends StatefulWidget {
  final Widget child;
  final bool isDark;

  const HorizontalCodeScroll({
    super.key,
    required this.child,
    required this.isDark,
  });

  @override
  State<HorizontalCodeScroll> createState() => _HorizontalCodeScrollState();
}

class _HorizontalCodeScrollState extends State<HorizontalCodeScroll> {
  final _controller = ScrollController();
  double _thumbFraction = 1.0;
  double _thumbOffset = 0.0;
  bool _hasOverflow = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final max = pos.maxScrollExtent;
    final viewport = pos.viewportDimension;

    final hasOverflow = max > 0;
    final thumbFraction = hasOverflow ? viewport / (max + viewport) : 1.0;
    final thumbOffset = hasOverflow ? pos.pixels / max : 0.0;

    if (hasOverflow != _hasOverflow ||
        (thumbFraction - _thumbFraction).abs() > 0.001 ||
        (thumbOffset - _thumbOffset).abs() > 0.001) {
      setState(() {
        _hasOverflow = hasOverflow;
        _thumbFraction = thumbFraction;
        _thumbOffset = thumbOffset;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
            },
            scrollbars: false,
          ),
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: widget.child,
          ),
        ),
        if (_hasOverflow)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                const minThumb = 24.0;
                final thumbWidth =
                    (_thumbFraction * trackWidth).clamp(minThumb, trackWidth);
                final maxLeft = trackWidth - thumbWidth;
                final thumbLeft =
                    (_thumbOffset * maxLeft).clamp(0.0, maxLeft);

                return SizedBox(
                  height: 4,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: thumbLeft,
                        width: thumbWidth,
                        top: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}