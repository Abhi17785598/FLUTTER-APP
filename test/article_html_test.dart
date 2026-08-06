// Locks the plain-text <-> HTML contract the Article Editor shares with the
// React portal. The mobile editor is plain text but `cms_posts.content_html`
// is rendered as HTML on the web, so a regression here would corrupt published
// articles rather than merely look wrong.
import 'package:flutter_test/flutter_test.dart';
import 'package:propcid_app/core/utils/article_html.dart';

void main() {
  test('plain -> html -> plain round trips', () {
    const src = 'First para line one\nline two\n\nSecond para with <tag> & "quotes"';
    final html = plainTextToHtml(src);
    expect(html, '<p>First para line one<br>line two</p>'
        '<p>Second para with &lt;tag&gt; &amp; &quot;quotes&quot;</p>');
    expect(htmlToPlainText(html), src);
    expect(isRichHtml(html), isFalse);
  });

  test('empty input', () {
    expect(plainTextToHtml('   '), '');
    expect(htmlToPlainText(''), '');
    expect(isRichHtml(null), isFalse);
    expect(isRichHtml(''), isFalse);
  });

  test('rich web markup is detected', () {
    expect(isRichHtml('<h1>Title</h1><p>x</p>'), isTrue);
    expect(isRichHtml('<p><strong>bold</strong></p>'), isTrue);
    expect(isRichHtml('<ul><li>a</li></ul>'), isTrue);
    expect(isRichHtml('<p style="text-align:center">x</p>'), isTrue);
    expect(isRichHtml('<img src="a.png">'), isTrue);
    expect(isRichHtml('<p>plain</p><p>two</p>'), isFalse);
  });

  test('escaping cannot inject markup', () {
    final html = plainTextToHtml('<script>alert(1)</script>');
    expect(html.contains('<script>'), isFalse);
    expect(html, '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>');
  });

  test('slug mirrors the web generator', () {
    expect(generateSlug('My Great Article!', randomSuffix: 'a1b2c3'),
        'my-great-article-a1b2c3');
    expect(generateSlug('   ', randomSuffix: 'a1b2c3'), 'a1b2c3');
  });

  test('read time', () {
    expect(estimateReadTime(''), 1);
    expect(estimateReadTime(List.filled(400, 'word').join(' ')), 2);
  });
}
