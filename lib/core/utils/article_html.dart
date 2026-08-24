/// Bridges the plain-text mobile editor and the HTML that `cms_posts` stores.
///
/// The web app authors articles with Tiptap and writes an HTML string to both
/// `content` and `content_html`. The mobile editor is plain text for now (no
/// rich-text dependency), so it must still produce and consume that same HTML
/// contract rather than storing raw text into an HTML column.
///
/// Round-tripping is only safe for the simple markup this file emits —
/// paragraphs and line breaks. Anything richer (headings, lists, bold, images,
/// inline styles) comes from the web editor and would be destroyed by editing
/// it as plain text, so [isRichHtml] detects it and the editor opens
/// read-only instead.
library;

/// Escapes the five XML entities so user text can never inject markup.
String _escape(String input) => input
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

String _unescape(String input) => input
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ')
    // Ampersand last, so "&amp;lt;" does not become "<".
    .replaceAll('&amp;', '&');

/// Plain text → the HTML stored in `content` / `content_html`.
///
/// Blank lines separate paragraphs; single newlines become `<br>`. Output
/// matches what a minimal Tiptap document produces, so the web renderer
/// displays it correctly.
String plainTextToHtml(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';

  return trimmed
      .split(RegExp(r'\n[ \t]*\n+'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty)
      .map((block) => '<p>${_escape(block).replaceAll('\n', '<br>')}</p>')
      .join();
}

/// The HTML stored in `content_html` → plain text for the editor.
///
/// Only meaningful when [isRichHtml] is false; callers must check first.
String htmlToPlainText(String html) {
  if (html.trim().isEmpty) return '';

  var text = html
      // Paragraph boundaries become blank lines.
      .replaceAll(RegExp(r'</p>\s*<p[^>]*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</?p[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

  return _unescape(text).trim();
}

/// True when [html] contains markup the plain-text editor cannot represent.
///
/// Only `<p>` and `<br>` survive a plain-text round trip. Anything else —
/// headings, lists, `<strong>`, `<img>`, links, alignment styles — means the
/// article was written on the web and editing it here would silently strip
/// its formatting.
bool isRichHtml(String? html) {
  if (html == null) return false;
  final source = html.trim();
  if (source.isEmpty) return false;

  final tags = RegExp(
    r'<\s*/?\s*([a-zA-Z][a-zA-Z0-9]*)',
    caseSensitive: false,
  ).allMatches(source).map((m) => m.group(1)!.toLowerCase()).toSet();

  const representable = {'p', 'br'};
  if (tags.difference(representable).isNotEmpty) return true;

  // A style/class/align attribute on a <p> is formatting too.
  return RegExp(
    r'<p[^>]*\s(style|class|align)\s*=',
    caseSensitive: false,
  ).hasMatch(source);
}

/// Rough word count used for the read-time estimate.
int wordCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

/// Read time in minutes at ~200 wpm, floored at 1.
///
/// The column defaults to 5 and the web form lets an author override it; the
/// mobile form derives a sensible starting value instead of shipping a raw
/// number input.
int estimateReadTime(String text) {
  final words = wordCount(text);
  if (words == 0) return 1;
  final minutes = (words / 200).ceil();
  return minutes < 1 ? 1 : minutes;
}

/// `my-article-title-a1b2c3` — mirrors `generateSlug` in ArticleWriteForm.tsx:
/// a slugified title plus a six-character suffix.
String generateSlug(String title, {required String randomSuffix}) {
  final base = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'(^-+)|(-+$)'), '');

  return base.isEmpty ? randomSuffix : '$base-$randomSuffix';
}
