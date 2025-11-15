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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['trackName'] = this.trackName;
    data['artistName'] = this.artistName;
    data['albumName'] = this.albumName;
    data['duration'] = this.duration;
    data['instrumental'] = this.instrumental;
    data['plainLyrics'] = this.plainLyrics;
    data['syncedLyrics'] = this.syncedLyrics;
    return data;
  }
}
