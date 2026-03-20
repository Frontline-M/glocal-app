import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../storage/hive_bootstrap.dart';
import 'speech_governance.dart';

final speechGovernanceStoreProvider = Provider<SpeechGovernanceStore>((ref) {
  final box = Hive.box<dynamic>(HiveBootstrap.runtimeBox);
  return HiveSpeechGovernanceStore(box);
});

final speechGovernanceServiceProvider =
    Provider<SpeechGovernanceService>((ref) {
  return SpeechGovernanceService(ref.read(speechGovernanceStoreProvider));
});
