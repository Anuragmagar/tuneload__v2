class Lyric {
  int? id;
  String? name;
  String? trackName;
  String? artistName;
  String? albumName;
  int? duration;
  bool? instrumental;
  String? plainLyrics;
  String? syncedLyrics;

  Lyric(
      {this.id,
      this.name,
      this.trackName,
      this.artistName,
      this.albumName,
      this.duration,
      this.instrumental,
      this.plainLyrics,
      this.syncedLyrics});

  Lyric.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    trackName = json['trackName'];
    artistName = json['artistName'];
    albumName = json['albumName'];
    duration = json['duration'];
    instrumental = json['instrumental'];
    plainLyrics = json['plainLyrics'];
    syncedLyrics = json['syncedLyrics'];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'trackName': trackName,
      'artistName': artistName,
      'albumName': albumName,
      'duration': duration,
      'instrumental': instrumental,
      'plainLyrics': plainLyrics,
      'syncedLyrics': syncedLyrics,
    };
  }
}
