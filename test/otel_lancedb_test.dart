// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_lancedb/otel_lancedb.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_lancedb-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('search records CLIENT span', () async {
    await tracedLancedbSearch<String>(
      table: 'docs',
      topK: 5,
      mode: 'hybrid',
      invoke: () async => const LancedbSearchResult(
        value: 'hits',
        resultCount: 5,
      ),
    );
    final a = attrsOf(spans.findSpanByName('lancedb search docs')!);
    expect(a['db.system'], 'lancedb');
    expect(a['lancedb.table'], 'docs');
    expect(a['lancedb.search.mode'], 'hybrid');
    expect(a['vector_db.search.top_k'], 5);
    expect(a['vector_db.search.result_count'], 5);
  });

  test('add records CLIENT span', () async {
    await tracedLancedbWrite<String>(
      operation: 'add',
      table: 'docs',
      rowCount: 100,
      invoke: () async => 'ok',
    );
    final a = attrsOf(spans.findSpanByName('lancedb add docs')!);
    expect(a['db.row_count'], 100);
  });

  test('suppression skips spans', () async {
    await runWithoutLancedbInstrumentationAsync(() async {
      await tracedLancedbSearch<String>(
        table: 'c',
        invoke: () async => const LancedbSearchResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('lancedb '), isEmpty);
  });
}
