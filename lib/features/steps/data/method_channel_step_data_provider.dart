import 'package:flutter/services.dart';

import '../domain/daily_step_snapshot.dart';
import '../domain/step_data_provider.dart';

class MethodChannelStepDataProvider implements StepDataProvider {
  MethodChannelStepDataProvider({
    required String channelName,
    required this.providerId,
    required this.source,
  }) : _channel = MethodChannel(channelName);

  final MethodChannel _channel;

  @override
  final String providerId;

  @override
  final StepDataSource source;

  @override
  Future<StepProviderAvailability> availability() async {
    try {
      final raw = await _channel.invokeMethod<String>('availability');
      switch (raw) {
        case 'available':
          return StepProviderAvailability.available;
        case 'permission_required':
          return StepProviderAvailability.permissionRequired;
        case 'unsupported':
          return StepProviderAvailability.unsupported;
        case 'unavailable':
        default:
          return StepProviderAvailability.unavailable;
      }
    } on MissingPluginException {
      return StepProviderAvailability.unsupported;
    } catch (_) {
      return StepProviderAvailability.unavailable;
    }
  }

  @override
  Future<bool> requestAccess() async {
    try {
      return await _channel.invokeMethod<bool>('requestAccess') ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<DailyStepSnapshot?> readToday(DateTime now) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readTodaySteps',
        <String, dynamic>{
          'atMillis': now.millisecondsSinceEpoch,
        },
      );
      if (result == null) {
        return null;
      }

      final stepsToday = (result['stepsToday'] as num?)?.toInt();
      if (stepsToday == null) {
        return null;
      }

      final capturedAtMillis = (result['capturedAtMillis'] as num?)?.toInt() ??
          now.millisecondsSinceEpoch;
      return DailyStepSnapshot(
        stepsToday: stepsToday,
        capturedAt: DateTime.fromMillisecondsSinceEpoch(capturedAtMillis),
        source: source,
      );
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
