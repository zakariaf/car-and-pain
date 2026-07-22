import 'package:flutter/material.dart';

/// Renders an inherently-LTR identifier — VIN, licence plate, phone, IBAN — as
/// an intact left-to-right run, correct even inside an RTL screen (F4-T5). The
/// forced [Directionality] stops the token from reordering, and tabular figures
/// keep its digits aligned. For embedding such a token *inline* within a
/// sentence, use `l10n`'s `ltrIsolate()` on the substring instead.
class LtrText extends StatelessWidget {
  const LtrText(
    this.data, {
    this.style,
    this.textAlign,
    this.semanticsLabel,
    super.key,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        data,
        textAlign: textAlign,
        semanticsLabel: semanticsLabel,
        style: base.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
