enum StepAnnouncementMode {
  summaryOnly,
  milestonesOnly,
  periodicAndSummary,
}

extension StepAnnouncementModeX on StepAnnouncementMode {
  String get storageValue {
    switch (this) {
      case StepAnnouncementMode.summaryOnly:
        return 'summary_only';
      case StepAnnouncementMode.milestonesOnly:
        return 'milestones_only';
      case StepAnnouncementMode.periodicAndSummary:
        return 'periodic_and_summary';
    }
  }

  String get label {
    switch (this) {
      case StepAnnouncementMode.summaryOnly:
        return 'Summary only';
      case StepAnnouncementMode.milestonesOnly:
        return 'Milestones only';
      case StepAnnouncementMode.periodicAndSummary:
        return 'Periodic + summary';
    }
  }

  bool get includesMilestones {
    switch (this) {
      case StepAnnouncementMode.summaryOnly:
        return false;
      case StepAnnouncementMode.milestonesOnly:
      case StepAnnouncementMode.periodicAndSummary:
        return true;
    }
  }

  bool get includesPeriodicSummaries {
    switch (this) {
      case StepAnnouncementMode.periodicAndSummary:
        return true;
      case StepAnnouncementMode.summaryOnly:
      case StepAnnouncementMode.milestonesOnly:
        return false;
    }
  }

  bool get includesEndOfDaySummary {
    switch (this) {
      case StepAnnouncementMode.summaryOnly:
      case StepAnnouncementMode.periodicAndSummary:
        return true;
      case StepAnnouncementMode.milestonesOnly:
        return false;
    }
  }
}

StepAnnouncementMode stepAnnouncementModeFromStorage(String? value) {
  switch (value) {
    case 'milestones_only':
      return StepAnnouncementMode.milestonesOnly;
    case 'periodic_and_summary':
      return StepAnnouncementMode.periodicAndSummary;
    case 'summary_only':
    default:
      return StepAnnouncementMode.summaryOnly;
  }
}
