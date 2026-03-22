import '../domain/culture_models.dart';

const List<CultureObservance> culturalObservances = [
  CultureObservance(
    id: 'global_01_01_new_year',
    region: 'Global',
    dateKey: '01-01',
    message: 'Today marks the beginning of a new year in many parts of the world.',
    weight: 3,
  ),
  CultureObservance(
    id: 'global_03_08_womens_day',
    region: 'Global',
    dateKey: '03-08',
    message: 'Today is International Women\'s Day, observed in many countries around the world.',
    weight: 2,
  ),
  CultureObservance(
    id: 'global_10_10_mental_health',
    region: 'Global',
    dateKey: '10-10',
    message: 'Today is World Mental Health Day, a reminder of the importance of emotional well-being.',
    weight: 2,
  ),
  CultureObservance(
    id: 'global_12_25_christmas',
    region: 'Global',
    dateKey: '12-25',
    message: 'Today is Christmas Day, observed by many people around the world.',
    weight: 2,
  ),
];
