// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_lancedb_suppression.dart';

const _tracerName = 'dartastic_otel_libs_lancedb';
const _systemValue = 'lancedb';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedLancedbSearch` callback.
class LancedbSearchResult<T> {
  const LancedbSearchResult({required this.value, this.resultCount});
  final T value;
  final int? resultCount;
}

/// Wraps a LanceDB vector / FTS search in a CLIENT span.
Future<T> tracedLancedbSearch<T>({
  required String table,
  required Future<LancedbSearchResult<T>> Function() invoke,
  int? topK,
  String? mode,
}) async {
  if (lancedbInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': 'search',
    'db.collection.name': table,
    'lancedb.table': table,
  };
  if (topK != null) m['vector_db.search.top_k'] = topK;
  if (mode != null) m['lancedb.search.mode'] = mode;

  final span = _tracer().startSpan(
    'lancedb search $table',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.resultCount != null) {
      span.addAttributes(OTel.attributes([
        OTel.attributeInt('vector_db.search.result_count', r.resultCount!),
      ]));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Wraps a LanceDB write op (add/delete/update) in a CLIENT span.
Future<T> tracedLancedbWrite<T>({
  required String operation,
  required String table,
  required Future<T> Function() invoke,
  int? rowCount,
}) async {
  if (lancedbInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': operation,
    'db.collection.name': table,
    'lancedb.table': table,
  };
  if (rowCount != null) m['db.row_count'] = rowCount;

  final span = _tracer().startSpan(
    'lancedb $operation $table',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
