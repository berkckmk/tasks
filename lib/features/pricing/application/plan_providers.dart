import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/plan_catalog.dart';
import '../domain/plan.dart';

/// The seam to swap for remote plan config later (see the TODO in
/// plan_catalog.dart) — everything else reads plans through this provider.
final plansProvider = Provider<List<Plan>>((ref) => planCatalog);
