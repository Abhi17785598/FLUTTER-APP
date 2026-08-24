// Locks the HTML <-> Quill Document round trip the rich-text Article Editor
// relies on: `cms_posts.content_html` must survive being loaded into the
// editor and saved back out with its formatting intact.
import 'package:flutter_test/flutter_test.dart';
import 'package:propcid_app/core/utils/article_content_converter.dart';

void main() {
  test('empty/null html loads as an empty document', () {
    expect(articleHtmlToDocument(null).toPlainText(), '\n');
    expect(articleHtmlToDocument('').toPlainText(), '\n');
  });

  test('paragraph and formatting round-trips', () {
    const html = '<p>Hello <strong>world</strong></p>';
    final document = articleHtmlToDocument(html);
    expect(document.toPlainText().trim(), 'Hello world');

    final out = articleDocumentToHtml(document);
    expect(out.contains('<strong>world</strong>'), isTrue);
  });

  test('heading, list and blockquote survive the round trip', () {
    const html = '<h1>Title</h1>'
        '<ul><li>one</li><li>two</li></ul>'
        '<blockquote>quoted</blockquote>';
    final out = articleDocumentToHtml(articleHtmlToDocument(html));
    expect(out.contains('<h1>Title</h1>'), isTrue);
    expect(out.contains('<ul>'), isTrue);
    expect(out.contains('<li>one</li>'), isTrue);
    expect(out.contains('<blockquote>'), isTrue);
  });
}
