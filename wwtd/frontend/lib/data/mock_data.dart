import 'package:wwtd/models/leaderboard_entry.dart';
import 'package:wwtd/models/prediction_market.dart';

const List<String> samplePeople = <String>[
  'Shoumik',
  'Alex',
  'Maya',
  'Jordan',
];

const String currentUsername = 'You';

final List<LeaderboardEntry> leaderboardData = <LeaderboardEntry>[
  const LeaderboardEntry(username: 'Aria', totalPoints: 3240, winRate: 68.5, isTrendingUp: true),
  const LeaderboardEntry(username: 'Kai', totalPoints: 3010, winRate: 65.1, isTrendingUp: true),
  const LeaderboardEntry(username: 'Nova', totalPoints: 2885, winRate: 62.8, isTrendingUp: false),
  const LeaderboardEntry(username: 'You', totalPoints: 2760, winRate: 63.4, isTrendingUp: true),
  const LeaderboardEntry(username: 'Ezra', totalPoints: 2620, winRate: 60.2, isTrendingUp: false),
  const LeaderboardEntry(username: 'Lena', totalPoints: 2505, winRate: 58.9, isTrendingUp: true),
  const LeaderboardEntry(username: 'Milo', totalPoints: 2430, winRate: 57.0, isTrendingUp: false),
  const LeaderboardEntry(username: 'Rhea', totalPoints: 2315, winRate: 56.8, isTrendingUp: true),
  const LeaderboardEntry(username: 'Owen', totalPoints: 2240, winRate: 54.2, isTrendingUp: false),
  const LeaderboardEntry(username: 'Sage', totalPoints: 2100, winRate: 52.6, isTrendingUp: true),
];

final List<PredictionMarket> marketData = <PredictionMarket>[
  PredictionMarket(
    id: 's-1',
    person: 'Shoumik',
    question: 'Will Shoumik go to the gym today?',
    dateLabel: 'Today',
    yesWageredPoints: 650,
    noWageredPoints: 350,
  ),
  PredictionMarket(
    id: 's-2',
    person: 'Shoumik',
    question: 'Will Shoumik finish all inbox emails tonight?',
    dateLabel: 'Today',
    yesWageredPoints: 430,
    noWageredPoints: 570,
  ),
  PredictionMarket(
    id: 's-3',
    person: 'Shoumik',
    question: 'Will Shoumik be at standup before 9:05 AM tomorrow?',
    dateLabel: 'Tomorrow',
    yesWageredPoints: 720,
    noWageredPoints: 280,
  ),
  PredictionMarket(
    id: 'a-1',
    person: 'Alex',
    question: 'Will Alex run 5k before dinner?',
    dateLabel: 'Today',
    yesWageredPoints: 540,
    noWageredPoints: 460,
  ),
  PredictionMarket(
    id: 'a-2',
    person: 'Alex',
    question: 'Will Alex finish the PR review by noon?',
    dateLabel: 'Tomorrow',
    yesWageredPoints: 620,
    noWageredPoints: 380,
  ),
  PredictionMarket(
    id: 'a-3',
    person: 'Alex',
    question: 'Will Alex drink less than 2 coffees tomorrow?',
    dateLabel: 'Tomorrow',
    yesWageredPoints: 300,
    noWageredPoints: 700,
  ),
  PredictionMarket(
    id: 'm-1',
    person: 'Maya',
    question: 'Will Maya ship the dashboard feature today?',
    dateLabel: 'Today',
    yesWageredPoints: 760,
    noWageredPoints: 240,
  ),
  PredictionMarket(
    id: 'm-2',
    person: 'Maya',
    question: 'Will Maya join game night at 8 PM?',
    dateLabel: 'Tomorrow',
    yesWageredPoints: 520,
    noWageredPoints: 480,
  ),
  PredictionMarket(
    id: 'm-3',
    person: 'Maya',
    question: 'Will Maya complete 10k steps tomorrow?',
    dateLabel: 'Tomorrow',
    yesWageredPoints: 455,
    noWageredPoints: 545,
  ),
  PredictionMarket(
    id: 'j-1',
    person: 'Jordan',
    question: 'Will Jordan close 3 sales calls today?',
    dateLabel: 'Today',
    yesWageredPoints: 410,
    noWageredPoints: 590,
  ),
  PredictionMarket(
    id: 'j-2',
    person: 'Jordan',
    question: 'Will Jordan wake up before 6:30 AM tomorrow?',
    dateLabel: 'Tomorrow',
    yesWageredPoints: 680,
    noWageredPoints: 320,
  ),
  PredictionMarket(
    id: 'j-3',
    person: 'Jordan',
    question: 'Will Jordan avoid sugar all day tomorrow?',
    dateLabel: 'Tomorrow',
    yesWageredPoints: 370,
    noWageredPoints: 630,
  ),
];
