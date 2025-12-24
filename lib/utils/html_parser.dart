import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

class HtmlParser {
  static String stripHtmlTags(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) {
      return '';
    }

    try {
      final document = html_parser.parse(htmlContent);
      final allText = _extractText(document.body);
      
      return allText.replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (e) {
      return htmlContent;
    }
  }

  static String _extractText(html_dom.Node? node) {
    if (node == null) return '';

    if (node is html_dom.Text) {
      return node.text;
    }

    if (node is html_dom.Element) {
      final buffer = StringBuffer();
      
      for (var child in node.nodes) {
        buffer.write(_extractText(child));
        
        if (['p', 'br', 'div', 'li'].contains(node.localName)) {
          buffer.write('\n');
        }
      }
      
      return buffer.toString();
    }

    return '';
  }

  static String parseAndFormatHtml(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) {
      return '';
    }

    try {
      final text = stripHtmlTags(htmlContent);
      return text;
    } catch (e) {
      return htmlContent;
    }
  }
}
