import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Thrown when the YouTube SDK cannot resolve a stream/URL.
/// Carries a human-friendly [message] intended for display to the user.
class YoutubeSdkException implements Exception {
  final String message;

  /// Whether the cause is YouTube rate-limiting (too many requests from this
  /// IP) — the most common cause when the app works on one network but not
  /// another.
  final bool isRateLimit;

  YoutubeSdkException(this.message, {this.isRateLimit = false});

  factory YoutubeSdkException.fromYoutube(Object error) {
    if (error is YoutubeSdkException) return error;
    final text = error.toString().toLowerCase();

    final isRateLimit = error is RequestLimitExceededException ||
        text.contains('requestlimitexceeded') ||
        text.contains('rate limit');

    // YouTube flags the IP as a bot and serves a CAPTCHA ("Sign in to confirm
    // you're not a bot") or blocks the actual stream with a 403.
    final isBotBlocked = text.contains("not a bot") ||
        text.contains("sign in to confirm") ||
        text.contains("reload") ||
        text.contains("response code: 403") ||
        text.contains("source error") ||
        text.contains("too many requests");

    final noStream = text.contains('no stream') ||
        text.contains('no audio') ||
        text.contains('unavailable') ||
        text.contains('unplayable');

    final isNetwork = text.contains('socket') ||
        text.contains('connection failed') ||
        text.contains('handshake') ||
        text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('network is unreachable') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused');

    String msg;
    if (isBotBlocked) {
      msg = 'YouTube has temporarily blocked this network (too many '
          'requests). Switch to Wi-Fi or another network, wait a while, '
          'and try again.';
    } else if (isRateLimit) {
      msg = 'YouTube is rate-limiting this network. Please wait a few '
          'seconds and try again, or switch to Wi-Fi/mobile data.';
    } else if (noStream) {
      msg = 'This track is not playable on YouTube right now.';
    } else if (isNetwork) {
      msg = 'No internet connection. Please check your network and try again.';
    } else {
      msg = 'Could not get the song link right now. Please try again.';
    }

    return YoutubeSdkException(
      msg,
      isRateLimit: isRateLimit || isBotBlocked,
    );
  }

  @override
  String toString() => message;
}
