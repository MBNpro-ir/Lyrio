import 'package:flutter_test/flutter_test.dart';
import 'package:lyrio/core/models.dart';

void main() {
  test(
    'LRC handles fractions, multiple timestamps, metadata and global offset',
    () {
      final lines = parseLrc(
        '[ar:Example]\n[offset:-250]\n[00:02.5][00:12.050]سلام\n[00:01.123]First\n[00:03.00]\n[invalid]',
      );
      expect(lines.map((e) => e.timeMs), [873, 2250, 2750, 11800]);
      expect(lines[1].text, 'سلام');
      expect(lines[2].text, '');
      expect(lines[3].text, 'سلام');
    },
  );
  test(
    'Clock selection handles pre-roll, exact boundary and backward seeks',
    () {
      final lines = parseLrc('[00:02]First\n[00:05]Second\n[00:09]Third');
      expect(activeLine(lines, 1999), -1);
      expect(activeLine(lines, 2000), 0);
      expect(activeLine(lines, 8900), 1);
      expect(activeLine(lines, 9000), 2);
      expect(activeLine(lines, 2100), 0);
      expect(activeLine([], 9000), -1);
    },
  );
  test('Enhanced LRC tags are removed while all words remain', () {
    final line = parseLrc('[00:03.00]<00:03.00>Hello <00:03.50>world').single;
    expect(line.text, 'Hello world');
  });
  test('Karaoke words carry per-word timings with global offset', () {
    final line =
        parseLrc('[offset:100]\n[00:03.00]<00:03.00>Hello <00:03.50>world')
            .single;
    expect(line.text, 'Hello world');
    expect(line.words.map((w) => w.timeMs), [3100, 3600]);
    expect(line.words.map((w) => w.text), ['Hello ', 'world']);
    expect(parseLrc('[00:03]Plain line').single.words, isEmpty);
  });
  test('First strong script decides direction for mixed Persian and Latin', () {
    expect(isRtl('۱۲۳ — سلام Lyrio'), true);
    expect(isRtl('2026 Hello سلام'), false);
    expect(isRtl('♪'), false);
  });
  test('A media notification without a clock never claims synchronization', () {
    final state = AppSnapshot({
      'track': {'title': 'Example', 'timingAvailable': false},
      'lyrics': {'status': 'ready', 'synced': '[00:01]word'},
    });
    expect(state.lines.length, 1);
    expect(state.synced, false);
  });
}
