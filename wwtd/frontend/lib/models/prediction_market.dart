class PredictionMarket {
  PredictionMarket({
    required this.id,
    required this.person,
    required this.question,
    required this.dateLabel,
    required this.yesWageredPoints,
    required this.noWageredPoints,
    this.userYesBet = 0,
    this.userNoBet = 0,
  });

  final String id;
  final String person;
  final String question;
  final String dateLabel;
  final double yesWageredPoints;
  final double noWageredPoints;
  final double userYesBet;
  final double userNoBet;

  double get totalPot => yesWageredPoints + noWageredPoints;
  double get yesPercent => totalPot == 0 ? 50 : (yesWageredPoints / totalPot) * 100;
  double get noPercent => totalPot == 0 ? 50 : (noWageredPoints / totalPot) * 100;

  PredictionMarket copyWith({
    double? yesWageredPoints,
    double? noWageredPoints,
    double? userYesBet,
    double? userNoBet,
  }) {
    return PredictionMarket(
      id: id,
      person: person,
      question: question,
      dateLabel: dateLabel,
      yesWageredPoints: yesWageredPoints ?? this.yesWageredPoints,
      noWageredPoints: noWageredPoints ?? this.noWageredPoints,
      userYesBet: userYesBet ?? this.userYesBet,
      userNoBet: userNoBet ?? this.userNoBet,
    );
  }
}
