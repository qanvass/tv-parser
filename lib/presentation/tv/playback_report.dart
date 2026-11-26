/// The full-screen players say here whether a stream really started.
///
/// Nothing listens unless a remote "play by name" request is waiting for the
/// answer, so the calls cost nothing during normal use.
abstract final class PlaybackReport {
  /// Gets 'playing', 'failed' or 'no_episode'.
  static void Function(String outcome)? listener;

  /// What was put on, in words ("Show, season 2 episode 3"). Names only.
  static String note = '';

  /// The player is showing the stream (playing and not buffering).
  static void playing() => listener?.call('playing');

  /// The player gave up on the stream (its "unavailable" screen is up).
  static void failed() => listener?.call('failed');

  /// A show's page could not find the episode that was asked for.
  static void noEpisode(String why) {
    if (listener == null) return;
    note = why;
    listener?.call('no_episode');
  }
}
