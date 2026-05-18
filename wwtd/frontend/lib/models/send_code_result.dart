class SendCodeResult {
  const SendCodeResult({
    required this.message,
    this.devCode,
  });

  final String message;
  final String? devCode;

  factory SendCodeResult.fromJson(Map<String, dynamic> json) {
    return SendCodeResult(
      message: json['message'] as String? ?? 'Code sent.',
      devCode: json['dev_code'] as String?,
    );
  }
}
