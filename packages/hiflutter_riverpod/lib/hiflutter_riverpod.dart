/// Optional Riverpod integration for HiFlutter (ADR-0002).
///
/// Provides Riverpod dependency-injection providers for HiFlutter contracts,
/// [HiPaginationNotifier] and [HiPaginationState] for Riverpod-backed
/// pagination, and [HiRiverpodBootstrap] for ordered application startup.
library;

export 'src/bootstrap.dart';
export 'src/pagination_notifier.dart';
export 'src/providers.dart';
