// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_lancedb/otel_lancedb.dart';

/// Traces Lancedb calls with OpenTelemetry.
///
/// `otel_lancedb` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Lancedb call in
/// [tracedLancedbSearch]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'lancedb-example');

  // Wraps a LanceDB vector / FTS search in a CLIENT span.
  final lancedbSearchId = await tracedLancedbSearch<String>(
    table: 'orders',
    topK: 1,
    mode: 'example',
    invoke: () async {
      // Make the Lancedb call here, then report what it returned.
      const id = 'lancedb_8f3a2c';
      return const LancedbSearchResult(value: id, resultCount: 3);
    },
  );
  OTelLog.info('tracedLancedbSearch returned $lancedbSearchId');

  // Wraps a LanceDB write op (add/delete/update) in a CLIENT span.
  final lancedbWriteId = await tracedLancedbWrite<String>(
    operation: 'create',
    table: 'orders',
    rowCount: 3,
    invoke: () async {
      // Make the Lancedb call here, then report what it returned.
      return 'lancedb_8f3a2c';
    },
  );
  OTelLog.info('tracedLancedbWrite create returned $lancedbWriteId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutLancedbInstrumentationAsync.
  await runWithoutLancedbInstrumentationAsync(
    () => tracedLancedbSearch<String>(
      table: 'orders',
      topK: 1,
      mode: 'example',
      invoke: () async {
        const id = 'lancedb_8f3a2c';
        return const LancedbSearchResult(value: id, resultCount: 3);
      },
    ),
  );

  await OTel.shutdown();
}
