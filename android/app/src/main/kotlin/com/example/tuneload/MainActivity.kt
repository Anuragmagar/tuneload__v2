package com.example.tuneload

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.jaudiotagger.audio.AudioFileIO
import org.jaudiotagger.tag.FieldKey
import org.jaudiotagger.tag.images.ArtworkFactory
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.tuneload/lyrics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "writeMetadata" -> {
                        try {
                            val path = call.argument<String>("path")!!
                            val title = call.argument<String>("title")
                            val artist = call.argument<String>("artist")
                            val album = call.argument<String>("album")
                            val albumArtist = call.argument<String>("albumArtist")
                            val year = call.argument<String>("year")
                            val artworkPath = call.argument<String>("artworkPath")
                            val lyrics = call.argument<String>("lyrics")

                            val file = File(path)
                            val audioFile = AudioFileIO.read(file)
                            val tag = audioFile.tagOrCreateAndSetDefault

                            if (!title.isNullOrBlank()) tag.setField(FieldKey.TITLE, title)
                            if (!artist.isNullOrBlank()) tag.setField(FieldKey.ARTIST, artist)
                            if (!album.isNullOrBlank()) tag.setField(FieldKey.ALBUM, album)
                            if (!albumArtist.isNullOrBlank()) tag.setField(FieldKey.ALBUM_ARTIST, albumArtist)
                            if (!year.isNullOrBlank()) tag.setField(FieldKey.YEAR, year)
                            if (!lyrics.isNullOrBlank()) tag.setField(FieldKey.LYRICS, lyrics)

                            if (!artworkPath.isNullOrBlank()) {
                                val artFile = File(artworkPath)
                                if (artFile.exists()) {
                                    val artwork = ArtworkFactory.createArtworkFromFile(artFile)
                                    tag.deleteArtworkField()
                                    tag.setField(artwork)
                                }
                            }

                            audioFile.commit()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WRITE_FAILED", e.message, null)
                        }
                    }
                    "writeLyrics" -> {
                        try {
                            val path = call.argument<String>("path")!!
                            val lyrics = call.argument<String>("lyrics")!!

                            val file = File(path)
                            val audioFile = AudioFileIO.read(file)
                            val tag = audioFile.tagOrCreateAndSetDefault
                            tag.setField(FieldKey.LYRICS, lyrics)
                            audioFile.commit()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WRITE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
