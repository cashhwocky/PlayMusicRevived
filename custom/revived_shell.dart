import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'main.dart';

// ── Classic Google Play Music Material 1 Palette ─────────────────────────────
const Color _gpmOrange = Color(0xFFFF5722);
const Color _gpmOrangeDark = Color(0xFFD84315);
bool get _gpmDark => appState.b('gpm_dark_theme', false);
Color get _gpmBg => _gpmDark ? const Color(0xFF181818) : const Color(0xFFF5F5F5);
Color get _gpmWhite => _gpmDark ? const Color(0xFF242424) : const Color(0xFFFFFFFF);
Color get _gpmText => _gpmDark ? const Color(0xFFF2F2F2) : const Color(0xFF212121);
Color get _gpmSub => _gpmDark ? const Color(0xFFA8A8A8) : const Color(0xFF757575);
Color get _gpmDivider => _gpmDark ? const Color(0xFF363636) : const Color(0xFFE0E0E0);
Color get _gpmArtBg => _gpmDark ? const Color(0xFF303030) : const Color(0xFFE0E0E0);
Color get _gpmArtCircle => _gpmDark ? const Color(0xFF525252) : const Color(0xFF9E9E9E);

YtAlbumPage? _memLikedPage;

/// Play Music's "Downloaded only" switch (drawer).
bool get _gpmDownloadedOnly => appState.b('gpm_downloaded_only', false);

// ── 2018 GOOGLE PLAY MUSIC QUEUE SHEET ──────────────────────────────────────
void _showGpm2018QueueSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFFFFFF),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.94,
      builder: (_, __) => ListenableBuilder(
        listenable: Listenable.merge([
          audioHandler.upNextRevision,
          audioHandler.libraryRevision,
          audioHandler.currentIndex,
        ]),
        builder: (_, __) {
          final upNext = audioHandler.upNext;
          final list = audioHandler.tracks;
          return SafeArea(
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFFFFFFF),
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.queue_music, color: Color(0xFFFF5722), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Queue', style: TextStyle(color: Color(0xFF212121), fontSize: 18, fontWeight: FontWeight.w600)),
                            Text('${list.length} songs', style: const TextStyle(color: Color(0xFF757575), fontSize: 12.5)),
                          ],
                        ),
                      ),
                      if (upNext.isNotEmpty)
                        TextButton(
                          onPressed: () => audioHandler.clearQueue(),
                          child: const Text('CLEAR UP NEXT', style: TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF757575)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE0E0E0)),
                if (upNext.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFEEEEEE),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: Text('UP NEXT (${upNext.length})', style: const TextStyle(color: Color(0xFF757575), fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ),
                  for (var q = 0; q < min(5, upNext.length); q++)
                    ListTile(
                      dense: true,
                      tileColor: const Color(0xFFFFFFFF),
                      leading: SizedBox(width: 40, height: 40, child: CustomAlbumArtwork(track: upNext[q])),
                      title: Text(upNext[q].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF212121), fontWeight: FontWeight.w500)),
                      subtitle: Text(upNext[q].artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF757575), fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFF757575)),
                        onPressed: () => audioHandler.removeFromQueue(q),
                      ),
                    ),
                  const Divider(height: 1, color: Color(0xFFE0E0E0)),
                ],
                Expanded(
                  child: Container(
                    color: const Color(0xFFFFFFFF),
                    child: ReorderableListView.builder(
                      itemCount: list.length,
                      onReorder: (oldIdx, newIdx) {
                        if (newIdx > oldIdx) newIdx -= 1;
                        audioHandler.moveTrack(oldIdx, newIdx);
                      },
                      itemBuilder: (_, i) {
                        final t = list[i];
                        final active = audioHandler.currentTrack?.id == t.id;
                        return ListTile(
                          key: ValueKey('gpmq_${t.id}_$i'),
                          tileColor: active ? const Color(0xFFFFF3E0) : const Color(0xFFFFFFFF),
                          leading: SizedBox(width: 44, height: 44, child: CustomAlbumArtwork(track: t)),
                          title: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: active ? const Color(0xFFFF5722) : const Color(0xFF212121),
                              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF757575), fontSize: 12.5)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (active) const Icon(Icons.equalizer, color: Color(0xFFFF5722)),
                              IconButton(
                                icon: const Icon(Icons.more_vert, color: Color(0xFF757575), size: 20),
                                onPressed: () => showPlayMusicTrackMenu(context, t),
                              ),
                            ],
                          ),
                          onTap: () {
                            audioHandler.playIndex(i);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

// ── 2018 ANDROID / GOOGLE PLAY MUSIC LYRICS PAGE ────────────────────────────
void _showGpm2018LyricsSheet(BuildContext context, TrackItem track) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => _Gpm2018LyricsPage(track: track)),
  );
}

class _Gpm2018LyricsPage extends StatefulWidget {
  final TrackItem track;
  const _Gpm2018LyricsPage({required this.track});
  @override
  State<_Gpm2018LyricsPage> createState() => _Gpm2018LyricsPageState();
}

class _Gpm2018LyricsPageState extends State<_Gpm2018LyricsPage> {
  bool _loading = true;
  String? _plain;
  List<(Duration, String)> _synced = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = Uri.encodeQueryComponent(widget.track.title);
      final a = Uri.encodeQueryComponent(widget.track.artist);
      final res = await http
          .get(Uri.parse('https://lrclib.net/api/get?artist_name=$a&track_name=$t'))
          .timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final sl = (j['syncedLyrics'] ?? '').toString().trim();
        final pl = (j['plainLyrics'] ?? '').toString().trim();
        if (sl.isNotEmpty) {
          final rx = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)');
          final out = <(Duration, String)>[];
          for (final line in sl.split('\n')) {
            final m = rx.firstMatch(line);
            if (m != null) {
              final mins = int.tryParse(m.group(1)!) ?? 0;
              final secs = double.tryParse(m.group(2)!) ?? 0.0;
              final txt = m.group(3)!.trim();
              if (txt.isNotEmpty) {
                out.add((Duration(milliseconds: mins * 60000 + (secs * 1000).round()), txt));
              }
            }
          }
          _synced = out;
        }
        if (pl.isNotEmpty) _plain = pl;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF212121),
        elevation: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF212121), fontSize: 16, fontWeight: FontWeight.w600)),
            Text(widget.track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF757575), fontSize: 12)),
          ],
        ),
      ),
      bottomNavigationBar: _gpmSecondaryMiniPlayer(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722)))
          : (_synced.isEmpty && (_plain == null || _plain!.isEmpty))
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No lyrics found for this track.', style: TextStyle(color: Color(0xFF757575), fontSize: 15)),
                  ),
                )
              : Container(
                  margin: const EdgeInsets.all(12),
                  child: Material(
                    color: const Color(0xFFFFFFFF),
                    elevation: 2,
                    borderRadius: BorderRadius.circular(2),
                    child: _synced.isNotEmpty
                        ? StreamBuilder<Duration>(
                            stream: audioHandler.player.positionStream,
                            builder: (_, snap) {
                              final pos = snap.data ?? Duration.zero;
                              int activeIdx = 0;
                              for (var i = 0; i < _synced.length; i++) {
                                if (pos >= _synced[i].$1) activeIdx = i;
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                itemCount: _synced.length,
                                itemBuilder: (_, i) {
                                  final isAct = i == activeIdx;
                                  return GestureDetector(
                                    onTap: () => audioHandler.seek(_synced[i].$1),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        _synced[i].$2,
                                        style: TextStyle(
                                          color: isAct ? const Color(0xFFFF5722) : const Color(0xFF424242),
                                          fontSize: isAct ? 19 : 16,
                                          fontWeight: isAct ? FontWeight.w700 : FontWeight.w400,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Text(_plain!, style: const TextStyle(color: Color(0xFF212121), fontSize: 16, height: 1.55)),
                          ),
                  ),
                ),
    );
  }
}

// ── 2018 GOOGLE PLAY MUSIC DOWNLOADS PAGE ───────────────────────────────────
class RevivedDownloadsPage extends StatelessWidget {
  const RevivedDownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([OfflineStore.revision, audioHandler.libraryRevision]),
      builder: (context, _) {
        final tracks = audioHandler.tracks.where(OfflineStore.isDownloaded).toList();
        return Scaffold(
          backgroundColor: const Color(0xFFEEEEEE),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFFFFF),
            foregroundColor: const Color(0xFF212121),
            elevation: 2,
            title: const Text('Downloads', style: TextStyle(color: Color(0xFF212121), fontSize: 19, fontWeight: FontWeight.w600)),
          ),
          bottomNavigationBar: _gpmSecondaryMiniPlayer(context),
          floatingActionButton: tracks.isEmpty
              ? null
              : FloatingActionButton(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  onPressed: () {
                    audioHandler.playYouTubeList(tracks, 0);
                    _openGpmPlayer(context);
                  },
                  child: const Icon(Icons.play_arrow, size: 30),
                ),
          body: tracks.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_download, size: 54, color: Color(0xFFBDBDBD)),
                      SizedBox(height: 12),
                      Text('No downloaded music yet', style: TextStyle(color: Color(0xFF757575), fontSize: 15, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(10),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                      child: Text(
                        '${tracks.length} downloaded songs • ${OfflineStore.formatBytes(OfflineStore.totalBytes)}',
                        style: const TextStyle(color: Color(0xFF757575), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Material(
                      color: const Color(0xFFFFFFFF),
                      elevation: 2,
                      borderRadius: BorderRadius.circular(2),
                      child: Column(
                        children: [
                          for (var i = 0; i < tracks.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 72, color: Color(0xFFE0E0E0)),
                            ListTile(
                              leading: SizedBox(width: 46, height: 46, child: CustomAlbumArtwork(track: tracks[i])),
                              title: Text(tracks[i].title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF212121), fontSize: 15, fontWeight: FontWeight.w500)),
                              subtitle: Text(tracks[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF757575), fontSize: 12.5)),
                              trailing: const Icon(Icons.check_circle, color: Color(0xFFFF5722), size: 20),
                              onTap: () {
                                audioHandler.playYouTubeList(tracks, i);
                                _openGpmPlayer(context);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 72),
                  ],
                ),
        );
      },
    );
  }
}


Widget _gpmSecondaryMiniPlayer(BuildContext context) {
  return ValueListenableBuilder<int>(
    valueListenable: audioHandler.currentIndex,
    builder: (context, _, __) {
      final track = audioHandler.currentTrack;
      if (track == null) return const SizedBox.shrink();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_gpmShouldSuppressPlayer()) _openGpmPlayer(context);
        },
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0.0;
          if (v < -250) {
            audioHandler.skipToNext();
          } else if (v > 250) {
            audioHandler.skipToPreviousTrack();
          }
        },
        child: Material(
          color: const Color(0xFFFFFFFF),
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<Duration>(
                  stream: audioHandler.player.positionStream,
                  builder: (_, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = audioHandler.player.duration ?? Duration.zero;
                    final frac = dur.inMilliseconds > 0
                        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0;
                    return LinearProgressIndicator(
                      value: frac,
                      minHeight: 2,
                      backgroundColor: const Color(0xFFE0E0E0),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFF5722)),
                    );
                  },
                ),
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CustomAlbumArtwork(track: track),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF212121),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF757575),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StreamBuilder<PlaybackState>(
                        stream: audioHandler.playbackState,
                        builder: (_, snap) {
                          final playing = snap.data?.playing ?? audioHandler.player.playing;
                          return IconButton(
                            icon: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              color: const Color(0xFF212121),
                              size: 28,
                            ),
                            onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _gpm2017RepoLink(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    child: Material(
      color: const Color(0xFFFFFFFF),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: _gpmDivider, width: 1),
      ),
      child: InkWell(
        onTap: () async {
          const url = 'https://github.com/cashhwocky?tab=repositories';
          try {
            await const MethodChannel('com.alexlmp.app/media').invokeMethod('openUrl', {'url': url});
          } catch (_) {
            await Clipboard.setData(const ClipboardData(text: url));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.code, color: _gpmOrange, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Check out @cashhwocky's other stuff!", style: TextStyle(color: _gpmText, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('github.com/cashhwocky?tab=repositories', style: TextStyle(color: _gpmOrange, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, color: _gpmSub, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
}

int _gpmCrossfadeSecs() => int.tryParse(appState.str('crossfade_secs', '5')) ?? 5;
void _gpmSetCrossfadeSecs(int v) => appState.setStr('crossfade_secs', v.clamp(1, 12).toString());

DateTime? _gpmSuppressPlayerUntil;
bool _gpmShouldSuppressPlayer() {
  final u = _gpmSuppressPlayerUntil;
  return u != null && DateTime.now().isBefore(u);
}
void _gpmArmGuard([Duration d = const Duration(milliseconds: 1100)]) {
  _gpmSuppressPlayerUntil = DateTime.now().add(d);
}


/// 2016 Android (Lollipop/Marshmallow) Material 1 upward slide + scale + fade activity transition
Route<T> _gpmActivityRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final c = CurvedAnimation(parent: anim, curve: Curves.fastOutSlowIn, reverseCurve: Curves.easeInCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.0, 0.06), end: Offset.zero).animate(c),
          child: FadeTransition(opacity: c, child: child),
        );
      },
    );

/// Authentic Google Play Music slide-up Now Playing sheet transition (matches 00:00 -> 00:01)
void _openGpmPlayer(BuildContext context) {
  if (_gpmShouldSuppressPlayer()) return;
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => const RevivedPlayerScreen(),
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    ),
  );
}


/// Classic Play Music grey placeholder with circular music note icon
Widget _gpmPlaceholder({double iconSize = 42, bool isArtist = false}) => Container(
      color: _gpmArtBg,
      child: Center(
        child: Container(
          width: iconSize * 1.65,
          height: iconSize * 1.65,
          decoration: BoxDecoration(color: _gpmArtCircle, shape: BoxShape.circle),
          child: Icon(isArtist ? Icons.person_rounded : Icons.music_note_rounded, color: _gpmArtBg, size: iconSize),
        ),
      ),
    );

/// 2x2 Mosaic placeholder for Auto Playlists (matches 27.png)
Widget _gpmMosaicPlaceholder() => Container(
      color: _gpmArtBg,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_miniNoteDot(), _miniNoteDot()],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_miniNoteDot(), _miniNoteDot()],
          ),
        ],
      ),
    );

Widget _miniNoteDot() => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: _gpmArtCircle, shape: BoxShape.circle),
      child: Icon(Icons.music_note_rounded, color: _gpmArtBg, size: 22),
    );

Widget _gpmArt(TrackItem? track, {double? size}) {
  final url = track?.artworkUrl;
  if (url != null && url.isNotEmpty) {
    return Image.network(
      url,
      width: size ?? double.infinity,
      height: size ?? double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _gpmPlaceholder(iconSize: (size ?? 120) * 0.34),
    );
  }
  if (track != null && !track.isYouTube) {
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: size ?? 200, height: size ?? 200, child: CustomAlbumArtwork(track: track)),
    );
  }
  return _gpmPlaceholder(iconSize: (size ?? 120) * 0.34);
}

Widget _gpmNetArt(String? url, {double? size, bool isArtist = false}) {
  if (url != null && url.isNotEmpty) {
    return Image.network(
      url,
      width: size ?? double.infinity,
      height: size ?? double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _gpmPlaceholder(iconSize: (size ?? 120) * 0.34, isArtist: isArtist),
    );
  }
  return _gpmPlaceholder(iconSize: (size ?? 120) * 0.34, isArtist: isArtist);
}

/// Bigger artwork for the large 2018 cards (YouTube Music hands out tiny thumbs).
String? _gpmHiRes(String? url) {
  if (url == null || url.isEmpty) return url;
  if (url.contains('googleusercontent.com') || url.contains('ggpht.com')) {
    return url.replaceAll(RegExp(r'=w\d+-h\d+'), '=w800-h800').replaceAll(RegExp(r'=s\d+'), '=s800');
  }
  return url;
}

/// Everything you've played (YouTube Music and local), newest first. Persisted.
class _GpmRecents {
  static const _key = 'gpm_recents_v1';
  static const _max = 60;
  static final ValueNotifier<int> revision = ValueNotifier(0);
  static final List<Map<String, dynamic>> _items = [];
  static bool _loaded = false;

  static void load() {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = jsonDecode(appState.str(_key, '[]'));
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) _items.add(Map<String, dynamic>.from(e));
        }
      }
    } catch (_) {}
  }

  static String _idOf(Map<String, dynamic> m) =>
      m['local'] != null ? m['local'].toString() : 'yt_${m['videoId']}';

  static void record(TrackItem? t) {
    if (t == null) return;
    load();
    final entry = t.isYouTube ? t.toYtJson() : <String, dynamic>{'local': t.id};
    final id = t.isYouTube ? 'yt_${t.ytVideoId}' : t.id;
    if (_items.isNotEmpty && _idOf(_items.first) == id) return;
    _items.removeWhere((m) => _idOf(m) == id);
    _items.insert(0, entry);
    if (_items.length > _max) _items.removeRange(_max, _items.length);
    try {
      appState.setStr(_key, jsonEncode(_items));
    } catch (_) {}
    revision.value++;
  }

  static List<TrackItem> tracks() {
    load();
    final out = <TrackItem>[];
    for (var i = 0; i < _items.length; i++) {
      final m = _items[i];
      final local = m['local'];
      final t = local != null ? audioHandler.trackById(local.toString()) : TrackItem.fromYtJson(m, i);
      if (t != null) out.add(t);
    }
    return out;
  }
}

/// Round orange play button (the 2018 FAB).
Widget _gpmOrangeFab(VoidCallback onTap, {double size = 56}) => Material(
      color: _gpmOrange,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: const Color(0x66000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Icon(Icons.play_arrow, color: Colors.white, size: size * 0.56)),
      ),
    );

/// Big image on top, white info card below, orange play button sitting on the
/// seam. Everything lives in one box so the button is never cut off.
Widget _gpmHeroHeader({
  required double heroHeight,
  required Widget image,
  required Widget body,
  required VoidCallback onPlay,
}) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: heroHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.3, 1.0],
                      colors: [Color(0x73000000), Colors.transparent, Colors.transparent],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Material(color: _gpmWhite, elevation: 1, child: body),
        ],
      ),
      Positioned(right: 20, top: heroHeight - 28, child: _gpmOrangeFab(onPlay)),
    ],
  );
}

Widget _gpmLoadingScaffold(BuildContext context, String title, {String? error}) => Scaffold(
      backgroundColor: _gpmBg,
      bottomNavigationBar: _gpmSecondaryMiniPlayer(context),
      appBar: AppBar(
        backgroundColor: _gpmWhite,
        foregroundColor: _gpmText,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        title: Text(title, style: TextStyle(color: _gpmText, fontSize: 20, fontWeight: FontWeight.w500)),
      ),
      body: Center(
        child: error == null
            ? const CircularProgressIndicator(color: _gpmOrange)
            : Text(error, style: TextStyle(color: _gpmSub)),
      ),
    );

/// Detail page with a hero image: the back arrow floats over the picture and a
/// white top bar with the title fades in as you scroll past it.
class _GpmHeroScaffold extends StatefulWidget {
  final String title;
  final double heroHeight;
  final List<Widget> slivers;
  final List<Widget> Function(Color fg)? actions;
  const _GpmHeroScaffold({required this.title, required this.heroHeight, required this.slivers, this.actions});
  @override
  State<_GpmHeroScaffold> createState() => _GpmHeroScaffoldState();
}

class _GpmHeroScaffoldState extends State<_GpmHeroScaffold> {
  final ScrollController _ctrl = ScrollController();
  final ValueNotifier<double> _t = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final top = MediaQuery.of(context).padding.top;
      final start = widget.heroHeight - kToolbarHeight - top - 48;
      final v = ((_ctrl.offset - start) / 48).clamp(0.0, 1.0);
      if (v != _t.value) _t.value = v;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _gpmBg,
      bottomNavigationBar: _gpmSecondaryMiniPlayer(context),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _ctrl,
            slivers: [
              ...widget.slivers,
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _t,
              builder: (context, t, _) {
                final fg = Color.lerp(Colors.white, _gpmText, t)!;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: ((t > 0.5 && !_gpmDark) ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
                      .copyWith(statusBarColor: Colors.transparent),
                  child: Material(
                    color: _gpmWhite.withOpacity(t),
                    elevation: t >= 1.0 ? 3 : 0,
                    shadowColor: const Color(0x40000000),
                    child: Padding(
                      padding: EdgeInsets.only(top: top),
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color: fg,
                                shadows: t < 0.5 ? const [Shadow(color: Color(0x99000000), blurRadius: 8)] : null,
                              ),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Opacity(
                                opacity: t,
                                child: Text(widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: _gpmText, fontSize: 20, fontWeight: FontWeight.w500)),
                              ),
                            ),
                            ...?widget.actions?.call(fg),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Classic Play Music Orange Brand Mark
class RevivedBrandMark extends StatelessWidget {
  final double size;
  final String variant;
  const RevivedBrandMark({super.key, this.size = 44, this.variant = 'default'});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset('custom/assets/gpm_logo.png', fit: BoxFit.contain),
    );
  }
}

Future<void> _gpmGoToArtist(BuildContext context, TrackItem t) async {
  if (!t.isYouTube) {
    final local = audioHandler.tracks.where((x) => !x.isYouTube && x.artist == t.artist).toList();
    if (local.isNotEmpty) {
      Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.custom(title: t.artist, subtitle: 'Artist', tracks: local)));
    }
    return;
  }
  try {
    final links = await YouTubeMusic.trackLinks(t.ytVideoId!);
    if (!context.mounted) return;
    if (links.artistUrl != null && links.artistUrl!.isNotEmpty) {
      Navigator.of(context).push(_gpmActivityRoute(RevivedArtistPage(url: links.artistUrl!, name: links.artistName ?? t.artist)));
      return;
    }
    final found = await YouTubeMusic.searchArtists(t.artist);
    if (!context.mounted) return;
    if (found.isNotEmpty) {
      Navigator.of(context).push(_gpmActivityRoute(RevivedArtistPage(url: found.first.url, name: found.first.name, initialThumb: found.first.thumbnail)));
    }
  } catch (_) {}
}

Future<void> _gpmGoToAlbum(BuildContext context, TrackItem t) async {
  if (!t.isYouTube) {
    final local = audioHandler.tracks.where((x) => !x.isYouTube && x.album == t.album).toList();
    if (local.isNotEmpty) {
      Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.custom(title: t.album, subtitle: t.artist, tracks: local)));
    }
    return;
  }
  try {
    final links = await YouTubeMusic.trackLinks(t.ytVideoId!);
    if (!context.mounted) return;
    final ref = links.albumBrowseId ?? links.albumUrl;
    if (ref != null && ref.isNotEmpty) {
      Navigator.of(context).push(_gpmActivityRoute(RevivedAlbumPage(url: ref, initialTitle: links.albumTitle ?? t.album, initialThumb: links.albumThumbnail ?? t.artworkUrl)));
    }
  } catch (_) {}
}

// ── 2018 PLAY MUSIC MENUS (⋮) ────────────────────────────────────────────────
/// Opens any YouTube Music card the Play Music way (songs start playing).
void gpmOpenShelfItem(BuildContext context, YtShelfItem it) {
  if (it.kind == 'album') {
    Navigator.of(context).push(_gpmActivityRoute(RevivedAlbumPage(url: it.id, initialTitle: it.title, initialThumb: it.thumbnail)));
  } else if (it.kind == 'artist') {
    Navigator.of(context).push(_gpmActivityRoute(RevivedArtistPage(url: it.id, name: it.title, initialThumb: it.thumbnail)));
  } else if (it.kind == 'playlist') {
    Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.youtube(playlistId: it.id, title: it.title, thumbnail: it.thumbnail)));
  } else {
    audioHandler.playYouTubeTrack(YouTubeMusic.trackFromShelf(it, it.subtitle));
    _openGpmPlayer(context);
  }
}

/// ⋮ for any YouTube Music card (song, album, playlist or artist).
void gpmShelfItemMenu(BuildContext context, YtShelfItem it) {
  if (it.kind == 'song' || it.kind == 'video') {
    showPlayMusicTrackMenu(context, YouTubeMusic.trackFromShelf(it, it.subtitle));
    return;
  }
  Future<List<TrackItem>> load() async {
    if (it.kind == 'album') return (await YouTubeMusic.album(it.id)).tracks;
    if (it.kind == 'playlist') return (await YouTubeMusic.playlistPage(it.id, title: it.title, thumbnail: it.thumbnail)).tracks;
    if (it.kind == 'artist') return (await YouTubeMusic.artist(it.id, it.title)).songs;
    return const <TrackItem>[];
  }
  showPlayMusicCollectionMenu(
    context,
    title: it.title,
    subtitle: it.subtitle,
    thumbnail: it.thumbnail,
    isArtist: it.kind == 'artist',
    artistName: it.kind == 'artist' ? it.title : null,
    load: load,
  );
}

void _gpmSnack(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14)),
    backgroundColor: const Color(0xFF323232),
    behavior: SnackBarBehavior.fixed,
    duration: const Duration(seconds: 2),
  ));
}

/// Play Music "Start radio": the song plus similar ones from YouTube Music.
Future<void> _gpmStartRadio(BuildContext context, TrackItem seed) async {
  _gpmSnack(context, 'Starting radio…');
  try {
    final q = seed.artist.isEmpty || seed.artist == 'Unknown Artist' ? seed.title : '${seed.artist} radio';
    final res = await YouTubeMusic.search(q);
    final list = <TrackItem>[seed, ...res.where((r) => r.id != seed.id).take(24)];
    if (seed.isYouTube || list.length > 1) {
      audioHandler.playYouTubeList(list, 0);
      if (context.mounted) _openGpmPlayer(context);
    }
  } catch (e) {
    if (context.mounted) _gpmSnack(context, "Couldn't start radio: $e");
  }
}

Future<void> _gpmStartArtistRadio(BuildContext context, String artist) async {
  _gpmSnack(context, 'Starting $artist radio…');
  try {
    final res = await YouTubeMusic.search('$artist radio');
    if (res.isEmpty) return;
    res.shuffle();
    audioHandler.playYouTubeList(res, 0);
    if (context.mounted) _openGpmPlayer(context);
  } catch (e) {
    if (context.mounted) _gpmSnack(context, "Couldn't start radio: $e");
  }
}

Widget _gpmMenuHeader(Widget art, String title, String subtitle) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          SizedBox(width: 48, height: 48, child: art),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _gpmText, fontSize: 16, fontWeight: FontWeight.w500)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmSub, fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );

Future<void> _gpmMenuSheet(BuildContext context, Widget header, List<Widget> Function(BuildContext ctx) items) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: _gpmWhite,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              Divider(height: 1, color: _gpmDivider),
              const SizedBox(height: 4),
              ...items(ctx),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    ),
  );
}

/// ⋮ on any song: the full Google Play Music song menu.
void showPlayMusicTrackMenu(BuildContext context, TrackItem track, {bool inPlayer = false}) {
  _gpmMenuSheet(
    context,
    _gpmMenuHeader(_gpmArt(track, size: 48), track.title, track.artist),
    (ctx) {
      final liked = appState.isLiked(track.id);
      return [
        _gpmMenuTile(Icons.sensors, 'Start radio', () {
          Navigator.pop(ctx);
          _gpmStartRadio(context, track);
        }),
        if (!inPlayer) ...[
          _gpmMenuTile(Icons.queue_play_next, 'Play next', () {
            Navigator.pop(ctx);
            audioHandler.addToQueue([track], next: true);
            _gpmSnack(context, 'Added 1 song to the queue');
          }),
          _gpmMenuTile(Icons.add_to_queue, 'Add to queue', () {
            Navigator.pop(ctx);
            audioHandler.addToQueue([track]);
            _gpmSnack(context, 'Added 1 song to the queue');
          }),
        ],
        _gpmMenuTile(Icons.playlist_add, 'Add to playlist', () {
          Navigator.pop(ctx);
          _gpmAddToPlaylistDialog(context, [track]);
        }),
        _gpmMenuTile(Icons.person, 'Go to artist', () {
          Navigator.pop(ctx);
          _gpmGoToArtist(context, track);
        }),
        _gpmMenuTile(Icons.album, 'Go to album', () {
          Navigator.pop(ctx);
          _gpmGoToAlbum(context, track);
        }),
        if (track.isYouTube)
          _gpmMenuTile(
            OfflineStore.isDownloaded(track) ? Icons.offline_pin : Icons.file_download,
            OfflineStore.isDownloaded(track) ? 'Remove download' : 'Download',
            () {
              Navigator.pop(ctx);
              final was = OfflineStore.isDownloaded(track);
              toggleOffline(track);
              _gpmSnack(context, was ? 'Download removed' : 'Downloading "${track.title}"');
            },
          ),
        _gpmMenuTile(liked ? Icons.thumb_up : Icons.thumb_up_outlined, liked ? 'Remove thumbs up' : 'Thumbs up', () {
          Navigator.pop(ctx);
          appState.toggleLike(track.id);
          _gpmSnack(context, liked ? 'Removed thumbs up' : 'Added to Thumbs up');
        }),
        _gpmMenuTile(Icons.subject, 'Lyrics', () {
          Navigator.pop(ctx);
          _showGpm2018LyricsSheet(context, track);
        }),
        _gpmMenuTile(Icons.share, 'Share', () {
          Navigator.pop(ctx);
          shareTrack(track);
        }),
        if (inPlayer) ...[
          Divider(height: 9, color: _gpmDivider),
          _gpmMenuTile(Icons.playlist_add_check, 'Save queue', () {
            Navigator.pop(ctx);
            final q = <TrackItem>[if (audioHandler.currentTrack != null) audioHandler.currentTrack!, ...audioHandler.upNext];
            _gpmAddToPlaylistDialog(context, q);
          }),
          _gpmMenuTile(Icons.clear_all, 'Clear queue', () {
            Navigator.pop(ctx);
            audioHandler.clearQueue();
            _gpmSnack(context, 'Queue cleared');
          }),
          _gpmMenuTile(Icons.info_outline, 'Song info', () {
            Navigator.pop(ctx);
            showTrackInfoDialog(context, track);
          }),
        ],
      ];
    },
  );
}

/// ⋮ on an album, playlist or artist card: Play Music's collection menu.
/// [load] fetches the songs only when an action needs them.
void showPlayMusicCollectionMenu(
  BuildContext context, {
  required String title,
  String subtitle = '',
  String? thumbnail,
  Widget? art,
  bool isArtist = false,
  String? artistName,
  required Future<List<TrackItem>> Function() load,
}) {
  Future<void> withTracks(void Function(List<TrackItem> t) f) async {
    try {
      final t = await load();
      if (t.isEmpty) {
        if (context.mounted) _gpmSnack(context, 'No songs found');
        return;
      }
      f(t);
    } catch (e) {
      if (context.mounted) _gpmSnack(context, "Couldn't load songs: $e");
    }
  }

  _gpmMenuSheet(
    context,
    _gpmMenuHeader(art ?? _gpmNetArt(thumbnail, size: 48, isArtist: isArtist), title, subtitle),
    (ctx) => [
      _gpmMenuTile(Icons.play_arrow, 'Play', () {
        Navigator.pop(ctx);
        withTracks((t) {
          audioHandler.playYouTubeList(t, 0);
          _openGpmPlayer(context);
        });
      }),
      _gpmMenuTile(Icons.shuffle, 'Shuffle', () {
        Navigator.pop(ctx);
        withTracks((t) {
          audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
          audioHandler.playYouTubeList(t, Random().nextInt(t.length));
          _openGpmPlayer(context);
        });
      }),
      if (artistName != null && artistName.isNotEmpty)
        _gpmMenuTile(Icons.sensors, 'Start radio', () {
          Navigator.pop(ctx);
          _gpmStartArtistRadio(context, artistName);
        }),
      _gpmMenuTile(Icons.queue_play_next, 'Play next', () {
        Navigator.pop(ctx);
        withTracks((t) {
          audioHandler.addToQueue(t, next: true);
          _gpmSnack(context, 'Added ${t.length} songs to the queue');
        });
      }),
      _gpmMenuTile(Icons.add_to_queue, 'Add to queue', () {
        Navigator.pop(ctx);
        withTracks((t) {
          audioHandler.addToQueue(t);
          _gpmSnack(context, 'Added ${t.length} songs to the queue');
        });
      }),
      _gpmMenuTile(Icons.playlist_add, 'Add to playlist', () {
        Navigator.pop(ctx);
        withTracks((t) => _gpmAddToPlaylistDialog(context, t));
      }),
      _gpmMenuTile(Icons.file_download, 'Download', () {
        Navigator.pop(ctx);
        withTracks((t) {
          final yt = t.where((x) => x.isYouTube).toList();
          if (yt.isEmpty) return;
          OfflineStore.downloadAll(yt);
          _gpmSnack(context, 'Downloading ${yt.length} songs');
        });
      }),
      _gpmMenuTile(Icons.share, 'Share', () {
        Navigator.pop(ctx);
        withTracks((t) => shareTrack(t.first));
      }),
    ],
  );
}

/// Play Music's white "Add to playlist" dialog.
void _gpmAddToPlaylistDialog(BuildContext context, List<TrackItem> tracks) {
  if (tracks.isEmpty) return;
  void addTo(Playlist pl) {
    for (final t in tracks) {
      final lib = t.isYouTube ? audioHandler.ensureInLibrary(t) : t;
      appState.addToPlaylist(pl.id, lib.id);
    }
    _gpmSnack(context, tracks.length == 1 ? 'Added 1 song to ${pl.name}' : 'Added ${tracks.length} songs to ${pl.name}');
  }

  Future<void> newPlaylist() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: _gpmWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        title: Text('New playlist', style: TextStyle(color: _gpmText, fontWeight: FontWeight.w500)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          cursorColor: _gpmOrange,
          style: TextStyle(color: _gpmText),
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: _gpmSub),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _gpmOrange, width: 2)),
          ),
          onSubmitted: (v) => Navigator.pop(dctx, v),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _gpmOrange),
            onPressed: () => Navigator.pop(dctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _gpmOrange),
            onPressed: () => Navigator.pop(dctx, ctrl.text),
            child: const Text('CREATE PLAYLIST'),
          ),
        ],
      ),
    );
    final n = (name ?? '').trim();
    if (n.isEmpty) return;
    addTo(appState.createPlaylist(n));
  }

  showDialog<void>(
    context: context,
    builder: (dctx) => AlertDialog(
      backgroundColor: _gpmWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
      contentPadding: const EdgeInsets.only(bottom: 8),
      title: Text('Add to playlist', style: TextStyle(color: _gpmText, fontSize: 20, fontWeight: FontWeight.w500)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add, color: _gpmOrange),
              title: const Text('NEW PLAYLIST', style: TextStyle(color: _gpmOrange, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              onTap: () {
                Navigator.pop(dctx);
                newPlaylist();
              },
            ),
            for (final pl in appState.playlists)
              ListTile(
                leading: Icon(Icons.queue_music, color: _gpmSub),
                title: Text(pl.name, style: TextStyle(color: _gpmText)),
                subtitle: Text('${pl.trackIds.length} songs', style: TextStyle(color: _gpmSub, fontSize: 12.5)),
                onTap: () {
                  Navigator.pop(dctx);
                  addTo(pl);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _gpmMenuTile(IconData icon, String label, VoidCallback onTap) => ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: 0.5),
      leading: Icon(icon, color: _gpmSub, size: 23),
      title: Text(label, style: TextStyle(color: _gpmText, fontSize: 15.5)),
      onTap: onTap,
    );

// ═════════════════════════════════════════════════════════════════════════════
// 1. GOOGLE PLAY MUSIC WELCOME / SETUP SCREEN (With Skip Button!)
// ═════════════════════════════════════════════════════════════════════════════
class RevivedSetupScreen extends StatefulWidget {
  const RevivedSetupScreen({super.key});
  @override
  State<RevivedSetupScreen> createState() => _RevivedSetupScreenState();
}

class _RevivedSetupScreenState extends State<RevivedSetupScreen> {
  bool _storageOk = false;
  bool _signingIn = false;

  Future<void> _grantStorage() async {
    final ok = await ensureMediaPermissions();
    if (mounted) setState(() => _storageOk = ok);
  }

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    try {
      await YouTubeMusic.signIn();
    } catch (_) {}
    if (mounted) setState(() => _signingIn = false);
  }

  void _finish() {
    appState.setB('setup_done', true);
    appState.setStr('home_mode', 'youtube');
    Navigator.of(context).pushReplacement(_gpmActivityRoute(const AlexLmpRoot()));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: _gpmOrangeDark, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: _gpmBg,
        body: ValueListenableBuilder<YtAccount>(
          valueListenable: ytAccount,
          builder: (_, acc, __) {
            final signedIn = acc.signedIn;
            return Column(
              children: [
                // Classic 2015 Material 1 Orange Setup Header Banner
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(24, top + 28, 24, 26),
                  decoration: const BoxDecoration(
                    color: _gpmOrange,
                    boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.headphones, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Play Music Revived',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500, letterSpacing: 0.1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Listen to YouTube Music & your device library',
                        style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 14, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),

                // Classic Material 1 Setup List (1px dividers, sharp checkboxes, orange section headers)
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 18, 16, 6),
                        child: Text('DEVICE PERMISSIONS',
                            style: TextStyle(color: _gpmOrange, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      ),
                      Container(
                        color: _gpmWhite,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Icon(
                            _storageOk ? Icons.check_box : Icons.check_box_outline_blank,
                            color: _storageOk ? _gpmOrange : _gpmSub,
                            size: 24,
                          ),
                          title: Text(
                            _storageOk ? 'Storage & media allowed' : 'Allow local music access',
                            style: TextStyle(color: _gpmText, fontSize: 15.5, fontWeight: FontWeight.w400),
                          ),
                          subtitle: Text(
                            'Scan audio files & show lock-screen controls',
                            style: TextStyle(color: _gpmSub, fontSize: 13),
                          ),
                          onTap: _storageOk ? null : _grantStorage,
                        ),
                      ),
                      Divider(height: 1, color: _gpmDivider),

                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 6),
                        child: Text('GOOGLE ACCOUNT',
                            style: TextStyle(color: _gpmOrange, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      ),
                      Container(
                        color: _gpmWhite,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: _signingIn
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.2, color: _gpmOrange))
                              : Icon(
                                  signedIn ? Icons.check_box : Icons.account_circle,
                                  color: signedIn ? _gpmOrange : _gpmSub,
                                  size: 26,
                                ),
                          title: Text(
                            signedIn ? (acc.name ?? 'Signed in') : 'Choose account',
                            style: TextStyle(color: _gpmText, fontSize: 15.5, fontWeight: FontWeight.w400),
                          ),
                          subtitle: Text(
                            signedIn ? 'YouTube Music playlists & Thumbs up synced' : 'Tap to sign in with YouTube Music',
                            style: TextStyle(color: _gpmSub, fontSize: 13),
                          ),
                          trailing: signedIn
                              ? null
                              : const Text('SIGN IN', style: TextStyle(color: _gpmOrange, fontSize: 13, fontWeight: FontWeight.w600)),
                          onTap: (signedIn || _signingIn) ? null : _signIn,
                        ),
                      ),
                      Divider(height: 1, color: _gpmDivider),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
                        child: Text(
                          'You can skip signing in and still play local music or search YouTube Music anytime.',
                          style: TextStyle(color: _gpmSub, fontSize: 12.5, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                // Classic Android Setup Wizard Bottom Navigation Bar (SKIP | GET STARTED)
                Container(
                  decoration: BoxDecoration(
                    color: _gpmWhite,
                    border: Border(top: BorderSide(color: _gpmDivider, width: 1)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: _gpmSub,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: _finish,
                            child: const Text('SKIP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _gpmOrange,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            ),
                            onPressed: _finish,
                            child: Text(
                              signedIn ? 'GET STARTED' : 'CONTINUE',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. CLASSIC GOOGLE PLAY MUSIC SHELL (Matches 26.png - 31.png!)
// ═════════════════════════════════════════════════════════════════════════════
class RevivedAppShell extends StatefulWidget {
  final List<TrackItem> tracks;
  final Widget Function(AppPalette pal)? aiChatBuilder;
  const RevivedAppShell({super.key, required this.tracks, this.aiChatBuilder});
  @override
  State<RevivedAppShell> createState() => _RevivedAppShellState();
}

class _RevivedAppShellState extends State<RevivedAppShell> with TickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabCtrl;
  late final TabController _browseCtrl;
  Future<List<TrackItem>>? _chartsFuture;
  Future<List<YtAlbum>>? _newFuture;
  // 2018 bottom tab bar: 0 = Home, 1 = Recents, 2 = Library, 3 = Browse
  int _tab = 0;
  bool _searchMode = false;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<TrackItem> _songRes = [];
  List<YtArtist> _artistRes = [];
  List<YtAlbum> _albumRes = [];

  Future<List<YtShelf>>? _ytFeedFuture;
  Future<List<YtPlaylistRef>>? _ytPlFuture;

  bool _backgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabCtrl = TabController(length: 5, vsync: this);
    _browseCtrl = TabController(length: 3, vsync: this);
    _ytFeedFuture = YouTubeMusic.homeFeed();
    _ytPlFuture = YouTubeMusic.libraryPlaylists();
    _preloadLiked();
    appState.setB('update_check', false);
    _GpmRecents.load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _GpmRecents.record(audioHandler.currentTrack));
    audioHandler.currentIndex.addListener(_onTrackChanged);
  }

  void _onTrackChanged() => _GpmRecents.record(audioHandler.currentTrack);

  void _selectTab(int i) {
    setState(() {
      _tab = i;
      if (_searchMode) {
        _searchMode = false;
        _searchCtrl.clear();
        _songRes = [];
        _artistRes = [];
        _albumRes = [];
      }
    });
  }

  void _startSearch(String q) {
    setState(() {
      _searchMode = true;
      _searchCtrl.text = q;
    });
    _runSearch(q);
  }

  void _openShelfItem(YtShelfItem it) {
    if (it.kind == 'album') {
      Navigator.of(context).push(_gpmActivityRoute(RevivedAlbumPage(url: it.id, initialTitle: it.title, initialThumb: it.thumbnail)));
    } else if (it.kind == 'artist') {
      Navigator.of(context).push(_gpmActivityRoute(RevivedArtistPage(url: it.id, name: it.title, initialThumb: it.thumbnail)));
    } else if (it.kind == 'playlist') {
      Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.youtube(playlistId: it.id, title: it.title, thumbnail: it.thumbnail)));
    } else {
      audioHandler.playYouTubeTrack(YouTubeMusic.trackFromShelf(it, it.subtitle));
      _openGpmPlayer(context);
    }
  }

  void _shelfItemMenu(YtShelfItem it) => gpmShelfItemMenu(context, it);

  void _playShelfItem(YtShelfItem it) {
    if (it.kind == 'song' || it.kind == 'video') {
      audioHandler.playYouTubeTrack(YouTubeMusic.trackFromShelf(it, it.subtitle));
      _openGpmPlayer(context);
    } else {
      _openShelfItem(it);
    }
  }

  Future<void> _preloadLiked() async {
    _memLikedPage ??= YouTubeMusic.cachedPlaylistPage('LM', title: 'Thumbs up');
    try {
      _memLikedPage = await YouTubeMusic.playlistPage('LM', title: 'Thumbs up');
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      _backgrounded = true;
    } else if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 350), () => _backgrounded = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    audioHandler.currentIndex.removeListener(_onTrackChanged);
    _debounce?.cancel();
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    _browseCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _songRes = [];
        _artistRes = [];
        _albumRes = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(trimmed));
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      final res = await Future.wait([
        YouTubeMusic.searchArtists(q).catchError((_) => <YtArtist>[]),
        YouTubeMusic.search(q).catchError((_) => <TrackItem>[]),
        YouTubeMusic.searchAlbums(q).catchError((_) => <YtAlbum>[]),
      ]);
      if (mounted) {
        setState(() {
          _artistRes = res[0] as List<YtArtist>;
          _songRes = res[1] as List<TrackItem>;
          _albumRes = res[2] as List<YtAlbum>;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  void _playList(List<TrackItem> list, int index) {
    if (list.isEmpty) return;
    audioHandler.playYouTubeList(list, index);
    _openGpmPlayer(context);
  }

  String get _tabTitle {
    switch (_tab) {
      case 1:
        return 'Recents';
      case 2:
        return 'Music library';
      case 3:
        return 'Browse';
      default:
        return 'Play Music';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, OfflineStore.revision, LibraryStore.revision, audioHandler.currentIndex, _GpmRecents.revision]),
      builder: (context, _) {
        return PopScope(
          canPop: !_searchMode && _tab == 0,
          onPopInvoked: (didPop) {
            if (didPop) return;
            if (_searchMode) {
              _selectTab(_tab);
            } else {
              _selectTab(0);
            }
          },
          child: Scaffold(
            backgroundColor: _gpmBg,
            drawer: _buildDrawer(context),
            appBar: AppBar(
              backgroundColor: _gpmWhite,
              foregroundColor: _gpmText,
              surfaceTintColor: Colors.transparent,
              elevation: 2,
              scrolledUnderElevation: 2,
              shadowColor: const Color(0x40000000),
              systemOverlayStyle: (_gpmDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                  .copyWith(statusBarColor: Colors.transparent),
              iconTheme: IconThemeData(color: _gpmSub),
              titleSpacing: _searchMode ? 0 : NavigationToolbar.kMiddleSpacing,
              leading: _searchMode
                  ? IconButton(
                      icon: Icon(Icons.arrow_back, color: _gpmSub),
                      onPressed: () => _selectTab(_tab),
                    )
                  : null,
              title: _searchMode
                  ? TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      onSubmitted: (q) {
                        if (q.trim().isNotEmpty) _rememberSearch(q.trim());
                        _runSearch(q);
                      },
                      style: TextStyle(color: _gpmText, fontSize: 17),
                      cursorColor: _gpmOrange,
                      decoration: InputDecoration(
                        hintText: 'Search music',
                        hintStyle: TextStyle(color: _gpmSub),
                        border: InputBorder.none,
                      ),
                    )
                  : Text(
                      _tabTitle,
                      style: TextStyle(color: _gpmText, fontSize: 20, fontWeight: FontWeight.w500),
                    ),
              actions: [
                if (_searchMode && _searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close, color: _gpmSub),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearchChanged('');
                    },
                  )
                else if (!_searchMode)
                  IconButton(
                    icon: Icon(Icons.search, color: _gpmSub),
                    onPressed: () => setState(() => _searchMode = true),
                  ),
              ],
              bottom: (!_searchMode && _tab == 3)
                  ? _gpmTabBar(_browseCtrl, const ['TOP CHARTS', 'NEW RELEASES', 'GENRES'], scrollable: false)
                  : (!_searchMode && _tab == 2)
                  ? TabBar(
                      dividerColor: Colors.transparent,
                      dividerHeight: 0,
                      controller: _tabCtrl,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: _gpmOrange,
                      indicatorWeight: 3.0,
                      indicatorSize: TabBarIndicatorSize.tab,
                      splashFactory: InkRipple.splashFactory,
                      overlayColor: WidgetStateProperty.all(_gpmOrange.withOpacity(0.10)),
                      labelColor: _gpmOrange,
                      unselectedLabelColor: _gpmSub,
                      labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                      tabs: const [
                        Tab(text: 'PLAYLISTS'),
                        Tab(text: 'ARTISTS'),
                        Tab(text: 'ALBUMS'),
                        Tab(text: 'SONGS'),
                        Tab(text: 'GENRES'),
                      ],
                    )
                  : null,
            ),
            body: Column(
              children: [
                Expanded(
                  child: _searchMode
                      ? _buildSearchBody()
                      : IndexedStack(
                          index: _tab,
                          children: [
                            _buildListenNowBody(),
                            _buildRecentsBody(),
                            TabBarView(
                              controller: _tabCtrl,
                              children: [
                                _buildPlaylistsTab(),
                                _buildArtistsTab(),
                                _buildAlbumsTab(),
                                _buildSongsTab(),
                                _buildGenresTab(),
                              ],
                            ),
                            TabBarView(
                              controller: _browseCtrl,
                              children: [
                                _buildChartsTab(),
                                _buildNewReleasesTab(),
                                _buildBrowseBody(),
                              ],
                            ),
                          ],
                        ),
                ),
                _buildDockedMiniPlayer(context),
                _buildBottomNav(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 2018 BOTTOM TAB BAR (Home · Recents · Library · Browse) ──────────────
  Widget _buildBottomNav() {
    const items = <(IconData, String)>[
      (Icons.home, 'Home'),
      (Icons.history, 'Recents'),
      (Icons.library_music, 'Library'),
      (Icons.explore, 'Browse'),
    ];
    return Material(
      color: _gpmWhite,
      elevation: 8,
      shadowColor: const Color(0x55000000),
      child: SafeArea(
        top: false,
        child: Container(
          height: 56,
          decoration: BoxDecoration(border: Border(top: BorderSide(color: _gpmDivider, width: 0.6))),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkResponse(
                    onTap: () => _selectTab(i),
                    highlightShape: BoxShape.rectangle,
                    containedInkWell: true,
                    splashColor: _gpmOrange.withOpacity(0.12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(items[i].$1, size: 24, color: (_tab == i && !_searchMode) ? _gpmOrange : _gpmSub),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          style: TextStyle(
                            color: (_tab == i && !_searchMode) ? _gpmOrange : _gpmSub,
                            fontSize: (_tab == i && !_searchMode) ? 12.5 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                          child: Text(items[i].$2),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2018 NAVIGATION DRAWER ────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    final dlOnly = _gpmDownloadedOnly;
    return Drawer(
      backgroundColor: _gpmWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ValueListenableBuilder<YtAccount>(
            valueListenable: ytAccount,
            builder: (_, acc, __) => InkWell(
              onTap: () {
                Navigator.pop(context);
                showYtAccountSheet(context);
              },
              child: Container(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 18, 16, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF7043), Color(0xFFE64A19)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      clipBehavior: Clip.antiAlias,
                      child: acc.photo != null && acc.photo!.isNotEmpty
                          ? Image.network(acc.photo!, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(12), child: RevivedBrandMark(size: 40)))
                          : const Padding(padding: EdgeInsets.all(12), child: RevivedBrandMark(size: 40)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(acc.signedIn ? (acc.name ?? 'YouTube Music') : 'Play Music',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                              Text(acc.signedIn ? 'YouTube Music account' : 'Tap to sign in to YouTube Music',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _drawerTile(Icons.home, 'Home', _tab == 0, () {
            _selectTab(0);
            Navigator.pop(context);
          }),
          _drawerTile(Icons.history, 'Recents', _tab == 1, () {
            _selectTab(1);
            Navigator.pop(context);
          }),
          _drawerTile(Icons.library_music, 'Music library', _tab == 2, () {
            _selectTab(2);
            Navigator.pop(context);
          }),
          _drawerTile(Icons.explore, 'Browse', _tab == 3, () {
            _selectTab(3);
            Navigator.pop(context);
          }),
          _drawerTile(Icons.offline_pin, 'Downloads', false, () {
            Navigator.pop(context);
            Navigator.of(context).push(_gpmActivityRoute(const RevivedDownloadsPage()));
          }),
          Divider(color: _gpmDivider, height: 16),
          ListTile(
            leading: Icon(Icons.offline_pin, color: dlOnly ? _gpmOrange : _gpmSub, size: 22),
            title: Text('Downloaded only', style: TextStyle(color: _gpmText, fontSize: 14.5, fontWeight: FontWeight.w500)),
            trailing: Switch(
              value: dlOnly,
              activeColor: _gpmOrange,
              activeTrackColor: _gpmOrange.withOpacity(0.5),
              onChanged: (v) => appState.setB('gpm_downloaded_only', v),
            ),
            onTap: () => appState.setB('gpm_downloaded_only', !dlOnly),
          ),
          Divider(color: _gpmDivider, height: 16),
          ListTile(
            leading: Icon(Icons.settings, color: _gpmSub, size: 22),
            title: Text('Settings', style: TextStyle(color: _gpmText, fontSize: 14.5, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              openRevivedSettings(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.help, color: _gpmSub, size: 22),
            title: Text('Help & feedback', style: TextStyle(color: _gpmText, fontSize: 14.5, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              checkRevivedUpdate(context, manual: true);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, bool selected, VoidCallback onTap) => Container(
        color: selected ? (_gpmDark ? const Color(0xFF323232) : const Color(0xFFEEEEEE)) : Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: selected ? _gpmOrange : _gpmSub, size: 22),
          title: Text(title, style: TextStyle(color: selected ? _gpmOrange : _gpmText, fontSize: 14.5, fontWeight: FontWeight.w500)),
          onTap: onTap,
        ),
      );

  // ── TAB 1: PLAYLISTS (Matches 27.png — Auto Playlists + Your Playlists) ──
  Widget _buildPlaylistsTab() {
    final recent = appState.recent.map(audioHandler.trackById).whereType<TrackItem>().toList();
    final local = widget.tracks.where((t) => !t.isYouTube).toList();
    final lastAdded = recent.isNotEmpty ? recent : local;

    return FutureBuilder<List<YtPlaylistRef>>(
      future: _ytPlFuture,
      initialData: YouTubeMusic.cachedLibrary(),
      builder: (context, snap) {
        final ytPls = snap.data ?? const <YtPlaylistRef>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          children: [
            Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text('Auto Playlists', style: TextStyle(color: _gpmText, fontSize: 18, fontWeight: FontWeight.w500)),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
              children: [
                _gpmSquareCard(
                  title: 'Last added',
                  cover: lastAdded.isNotEmpty ? _gpmArt(lastAdded.first) : _gpmMosaicPlaceholder(),
                  onTap: () => Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.custom(title: 'Last added', subtitle: '${lastAdded.length} songs', tracks: lastAdded))),
                  onPlay: () => _playList(lastAdded, 0),
                  onMore: () => showPlayMusicCollectionMenu(context, title: 'Last added', subtitle: 'Auto playlist', art: _gpmMosaicPlaceholder(), load: () async => lastAdded),
                ),
                _gpmSquareCard(
                  title: 'Thumbs up',
                  cover: _memLikedPage?.tracks.isNotEmpty == true ? _gpmArt(_memLikedPage!.tracks.first) : _gpmMosaicPlaceholder(),
                  onTap: () => Navigator.of(context).push(_gpmActivityRoute(const RevivedPlaylistPage.youtube(playlistId: 'LM', title: 'Thumbs up'))),
                  onPlay: () {
                    final list = _memLikedPage?.tracks ?? const <TrackItem>[];
                    if (list.isNotEmpty) _playList(list, 0);
                  },
                  onMore: () => showPlayMusicCollectionMenu(context, title: 'Thumbs up', subtitle: 'Auto playlist', art: _gpmMosaicPlaceholder(),
                      load: () async => (await YouTubeMusic.playlistPage('LM', title: 'Thumbs up')).tracks),
                ),
              ],
            ),
            if (ytPls.isNotEmpty || appState.playlists.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(4, 20, 4, 12),
                child: Text('Playlists', style: TextStyle(color: _gpmText, fontSize: 18, fontWeight: FontWeight.w500)),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.78,
                children: [
                  for (final pl in appState.playlists)
                    _gpmSquareCard(
                      title: pl.name,
                      cover: _gpmMosaicPlaceholder(),
                      onTap: () => Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.local(playlist: pl))),
                      onPlay: () {
                        final list = pl.trackIds.map(audioHandler.trackById).whereType<TrackItem>().toList();
                        _playList(list, 0);
                      },
                      onMore: () => showPlayMusicCollectionMenu(context, title: pl.name, subtitle: '${pl.trackIds.length} songs', art: _gpmMosaicPlaceholder(),
                          load: () async => pl.trackIds.map(audioHandler.trackById).whereType<TrackItem>().toList()),
                    ),
                  for (final ypl in ytPls)
                    _gpmSquareCard(
                      title: ypl.title,
                      cover: _gpmNetArt(ypl.thumbnail),
                      onTap: () => Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.youtube(playlistId: ypl.playlistId, title: ypl.title, thumbnail: ypl.thumbnail))),
                      onPlay: () async {
                        try {
                          final t = (await YouTubeMusic.playlistPage(ypl.playlistId, title: ypl.title, thumbnail: ypl.thumbnail)).tracks;
                          if (t.isNotEmpty && mounted) _playList(t, 0);
                        } catch (_) {}
                      },
                      onMore: () => showPlayMusicCollectionMenu(context, title: ypl.title, subtitle: 'Playlist', thumbnail: ypl.thumbnail,
                          load: () async => (await YouTubeMusic.playlistPage(ypl.playlistId, title: ypl.title, thumbnail: ypl.thumbnail)).tracks),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  // ── TAB 2: ARTISTS (Matches 28.png) ───────────────────────────────────────
  Widget _buildArtistsTab() {
    final byArtist = <String, List<TrackItem>>{};
    for (final t in widget.tracks) {
      byArtist.putIfAbsent(t.artist.isEmpty ? 'Unknown artist' : t.artist, () => []).add(t);
    }
    final list = byArtist.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    if (list.isEmpty) return Center(child: Text('No artists in library', style: TextStyle(color: _gpmSub)));

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.05),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final e = list[i];
        return _gpmSquareCard(
          title: e.key,
          cover: e.value.first.artworkUrl != null ? _gpmArt(e.value.first) : _gpmPlaceholder(iconSize: 38, isArtist: true),
          aspectRatio: 1.45,
          onTap: () => Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.custom(title: e.key, subtitle: '${e.value.length} songs', tracks: e.value))),
          onPlay: () => _playList(e.value, 0),
          onMore: () => showPlayMusicCollectionMenu(context, title: e.key, subtitle: '${e.value.length} songs', art: _gpmArt(e.value.first, size: 48),
              isArtist: true, artistName: e.key, load: () async => e.value),
        );
      },
    );
  }

  // ── TAB 3: ALBUMS (Matches 29.png) ────────────────────────────────────────
  Widget _buildAlbumsTab() {
    final byAlbum = <String, List<TrackItem>>{};
    for (final t in widget.tracks) {
      byAlbum.putIfAbsent(t.album.isEmpty ? 'Download' : t.album, () => []).add(t);
    }
    final list = byAlbum.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    if (list.isEmpty) return Center(child: Text('No albums in library', style: TextStyle(color: _gpmSub)));

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.78),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final e = list[i];
        final isPlayingAlbum = audioHandler.currentTrack?.album == e.key;
        return _gpmSquareCard(
          title: e.key,
          cover: _gpmArt(e.value.first),
          badgeIcon: isPlayingAlbum ? Icons.equalizer_rounded : Icons.play_arrow,
          subtitle: e.value.first.artist,
          onTap: () => Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.custom(title: e.key, subtitle: e.value.first.artist, tracks: e.value))),
          onPlay: () => _playList(e.value, 0),
          onMore: () => showPlayMusicCollectionMenu(context, title: e.key, subtitle: e.value.first.artist, art: _gpmArt(e.value.first, size: 48),
              artistName: e.value.first.artist, load: () async => e.value),
        );
      },
    );
  }

  // ── TAB 4: SONGS (Matches 30.png) ─────────────────────────────────────────
  Widget _buildSongsTab() {
    final songs = _gpmDownloadedOnly ? _downloadedTracks() : widget.tracks;
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No local songs yet', style: TextStyle(color: _gpmSub, fontSize: 15)),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _gpmOrange, foregroundColor: Colors.white),
              onPressed: () => setState(() => _searchMode = true),
              child: const Text('SEARCH YOUTUBE MUSIC'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      itemCount: songs.length,
      itemBuilder: (_, i) => _gpmSongCardRow(songs[i], () => _playList(songs, i)),
    );
  }

  // ── TAB 5: GENRES (Matches 31.png) ────────────────────────────────────────
  Widget _buildGenresTab() {
    const genres = ['Hip-Hop', 'R&B', 'Pop', 'Rock', 'Alternative', 'Electronic', 'Chill', 'Workout'];
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.05),
      itemCount: genres.length,
      itemBuilder: (_, i) => _gpmSquareCard(
        title: genres[i],
        cover: _gpmPlaceholder(iconSize: 36),
        aspectRatio: 1.45,
        showMore: false,
        onTap: () {
          setState(() {
            _searchMode = true;
            _searchCtrl.text = genres[i];
          });
          _runSearch(genres[i]);
        },
        onPlay: () {
          setState(() {
            _searchMode = true;
            _searchCtrl.text = genres[i];
          });
          _runSearch(genres[i]);
        },
      ),
    );
  }

  // ── LISTEN NOW (YouTube Music Home Feed in Play Music Cards) ──────────────
  List<TrackItem> _downloadedTracks() => [
        ...widget.tracks.where((t) => !t.isYouTube),
        ...OfflineStore.tracks(),
      ];

  // Home while "Downloaded only" is on: just what's on the phone.
  Widget _buildDownloadedHome() {
    final list = _downloadedTracks();
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.offline_pin, color: _gpmSub, size: 56),
              const SizedBox(height: 10),
              Text('No downloaded music', style: TextStyle(color: _gpmText, fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('Turn off "Downloaded only" in the menu to see everything', textAlign: TextAlign.center, style: TextStyle(color: _gpmSub, fontSize: 13.5)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      itemCount: list.length,
      itemBuilder: (_, i) => _gpmSongCardRow(list[i], () => _playList(list, i)),
    );
  }

  Widget _buildListenNowBody() {
    if (_gpmDownloadedOnly) return _buildDownloadedHome();
    return FutureBuilder<List<YtShelf>>(
      future: _ytFeedFuture,
      initialData: YouTubeMusic.cachedHomeFeed(),
      builder: (_, snap) {
        final shelves = (snap.data ?? const <YtShelf>[]).where((s) => s.items.isNotEmpty).toList();
        if (shelves.isEmpty && snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _gpmOrange));
        }
        if (shelves.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home, color: _gpmSub, size: 56),
                const SizedBox(height: 10),
                Text('Your recommendations will show up here', style: TextStyle(color: _gpmSub, fontSize: 15)),
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _gpmOrange, foregroundColor: Colors.white),
                  onPressed: () => setState(() => _searchMode = true),
                  child: const Text('SEARCH YOUTUBE MUSIC'),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: _gpmOrange,
          onRefresh: () async {
            final f = YouTubeMusic.homeFeed(refresh: true);
            setState(() => _ytFeedFuture = f);
            try {
              await f;
            } catch (_) {}
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            children: [
              _gpmLuckyCard(shelves),
              for (var s = 0; s < shelves.length && s < 10; s++) ...[
                _gpmHomeHeroCard(
                  eyebrow: shelves[s].title.isEmpty ? 'Recommended for you' : shelves[s].title,
                  it: shelves[s].items.first,
                ),
                if (shelves[s].items.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      height: 214,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: shelves[s].items.length - 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final it = shelves[s].items[i + 1];
                          return SizedBox(
                            width: 152,
                            child: _gpmSquareCard(
                              title: it.title,
                              subtitle: it.subtitle,
                              cover: _gpmNetArt(it.thumbnail, isArtist: it.kind == 'artist'),
                              onTap: () => _openShelfItem(it),
                              onPlay: () => _playShelfItem(it),
                              onMore: () => _shelfItemMenu(it),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Orange "I'm Feeling Lucky" card at the top of Home (2018 style).
  Widget _gpmLuckyCard(List<YtShelf> shelves) {
    void play() {
      final pool = <TrackItem>[];
      final seen = <String>{};
      void add(TrackItem t) {
        if (seen.add(t.id)) pool.add(t);
      }
      for (final t in _memLikedPage?.tracks ?? const <TrackItem>[]) {
        add(t);
      }
      for (final sh in shelves) {
        for (final it in sh.items) {
          if (it.kind == 'song' || it.kind == 'video') add(YouTubeMusic.trackFromShelf(it, it.subtitle));
        }
      }
      if (pool.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Like a few songs first to get a lucky mix')));
        return;
      }
      pool.shuffle();
      audioHandler.playYouTubeList(pool.take(50).toList(), 0);
      _openGpmPlayer(context);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _gpmOrange,
        elevation: 2,
        borderRadius: BorderRadius.circular(2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: play,
          child: AspectRatio(
            aspectRatio: 1.5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  right: -24,
                  top: -12,
                  child: Transform.rotate(
                    angle: -0.25,
                    child: Icon(Icons.card_giftcard, size: 190, color: Colors.white.withOpacity(0.20)),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 80,
                  bottom: 18,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("I'm Feeling Lucky",
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500, height: 1.15)),
                      Container(width: 32, height: 2, color: Colors.white, margin: const EdgeInsets.symmetric(vertical: 10)),
                      Text('An instant mix from your thumbs up and recommendations',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13.5)),
                    ],
                  ),
                ),
                Positioned(right: 16, bottom: 16, child: _gpmCardPlayButton(play)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Big full-width image card with title over a dark fade (2018 Home).
  Widget _gpmHomeHeroCard({required String eyebrow, required YtShelfItem it}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF212121),
        elevation: 2,
        borderRadius: BorderRadius.circular(2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openShelfItem(it),
          child: AspectRatio(
            aspectRatio: 1.25,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _gpmNetArt(_gpmHiRes(it.thumbnail), isArtist: it.kind == 'artist'),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1.0],
                      colors: [Colors.transparent, Color(0xE6000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 80,
                  bottom: 18,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12.5, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(it.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w500, height: 1.15)),
                      Container(width: 32, height: 2, color: _gpmOrange, margin: const EdgeInsets.symmetric(vertical: 9)),
                      if (it.subtitle.isNotEmpty)
                        Text(it.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13.5)),
                    ],
                  ),
                ),
                Positioned(right: 16, bottom: 16, child: _gpmCardPlayButton(() => _playShelfItem(it))),
                Positioned(
                  right: 2,
                  top: 2,
                  child: IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)]),
                    onPressed: () => _shelfItemMenu(it),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gpmCardPlayButton(VoidCallback onTap) => Material(
        color: Colors.white.withOpacity(0.92),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 46,
            height: 46,
            child: Icon(Icons.play_arrow, color: Color(0xFF616161), size: 28),
          ),
        ),
      );

  // ── RECENTS (everything you've played, newest first) ─────────────────────
  Widget _buildRecentsBody() {
    final recent = _GpmRecents.tracks().where((t) => !_gpmDownloadedOnly || !t.isYouTube || OfflineStore.isDownloaded(t)).toList();
    if (recent.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, color: _gpmSub, size: 56),
            const SizedBox(height: 10),
            Text('Nothing played yet', style: TextStyle(color: _gpmText, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Songs you play show up here', style: TextStyle(color: _gpmSub, fontSize: 13.5)),
          ],
        ),
      );
    }
    final cur = audioHandler.currentTrack?.id;
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.78),
      itemCount: recent.length,
      itemBuilder: (_, i) {
        final t = recent[i];
        return _gpmSquareCard(
          title: t.title,
          subtitle: t.artist,
          cover: _gpmArt(t),
          badgeIcon: t.id == cur ? Icons.equalizer_rounded : Icons.play_arrow,
          onTap: () => _playList(recent, i),
          onPlay: () => _playList(recent, i),
          onMore: () => showPlayMusicTrackMenu(context, t),
        );
      },
    );
  }

  // ── BROWSE (charts, new releases, genres & moods) ─────────────────────────
  static const List<(String, String, IconData, Color)> _browseGenres = [
    ('Hip-Hop', 'hip hop hits', Icons.mic, Color(0xFF6D4C41)),
    ('Pop', 'pop hits', Icons.star, Color(0xFFD81B60)),
    ('Rock', 'rock hits', Icons.bolt, Color(0xFF455A64)),
    ('R&B / Soul', 'r&b soul hits', Icons.favorite, Color(0xFF8E24AA)),
    ('Alternative', 'alternative rock', Icons.album, Color(0xFF00897B)),
    ('Metal', 'metal', Icons.whatshot, Color(0xFF263238)),
    ('Electronic', 'electronic dance', Icons.graphic_eq, Color(0xFF3949AB)),
    ('Country', 'country hits', Icons.landscape, Color(0xFFF4511E)),
    ('Chill', 'chill vibes', Icons.spa, Color(0xFF43A047)),
    ('Workout', 'workout music', Icons.fitness_center, Color(0xFFE53935)),
    ('Focus', 'focus music', Icons.headphones, Color(0xFF5E35B1)),
    ('Party', 'party hits', Icons.celebration, Color(0xFFFB8C00)),
  ];

  Widget _browseTile((String, String, IconData, Color) g, {double aspect = 1.5}) => Material(
        color: g.$4,
        elevation: 2,
        borderRadius: BorderRadius.circular(2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _startSearch(g.$2),
          child: AspectRatio(
            aspectRatio: aspect,
            child: Stack(
              children: [
                Positioned(right: -10, bottom: -10, child: Icon(g.$3, size: 84, color: Colors.white.withOpacity(0.22))),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Text(g.$1, maxLines: 2, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      );

  PreferredSizeWidget _gpmTabBar(TabController c, List<String> labels, {bool scrollable = true}) => TabBar(
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        controller: c,
        isScrollable: scrollable,
        tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
        indicatorColor: _gpmOrange,
        indicatorWeight: 3.0,
        indicatorSize: TabBarIndicatorSize.tab,
        splashFactory: InkRipple.splashFactory,
        overlayColor: WidgetStateProperty.all(_gpmOrange.withOpacity(0.10)),
        labelColor: _gpmOrange,
        unselectedLabelColor: _gpmSub,
        labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.4),
        tabs: [for (final l in labels) Tab(text: l)],
      );

  // TOP CHARTS: numbered list like Play Music's charts.
  Widget _buildChartsTab() {
    _chartsFuture ??= YouTubeMusic.search('top songs this week');
    return FutureBuilder<List<TrackItem>>(
      future: _chartsFuture,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _gpmOrange));
        final list = snap.data ?? const <TrackItem>[];
        if (list.isEmpty) {
          return Center(
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: _gpmOrange),
              onPressed: () => setState(() => _chartsFuture = YouTubeMusic.search('top songs this week')),
              child: Text(snap.hasError ? 'Couldn\'t load charts: ${snap.error}\nTAP TO RETRY' : 'TAP TO RETRY', textAlign: TextAlign.center),
            ),
          );
        }
        final cur = audioHandler.currentTrack?.id;
        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
          children: [
            Material(
              color: _gpmWhite,
              elevation: 2,
              borderRadius: BorderRadius.circular(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Text('Top songs', style: TextStyle(color: _gpmText, fontSize: 18, fontWeight: FontWeight.w500)),
                  ),
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 112, color: _gpmDivider),
                    InkWell(
                      onTap: () => _playList(list, i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text('${i + 1}', textAlign: TextAlign.center,
                                  style: TextStyle(color: _gpmText, fontSize: 15, fontWeight: FontWeight.w500)),
                            ),
                            SizedBox(width: 52, height: 52, child: _gpmArt(list[i], size: 52)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(list[i].title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: list[i].id == cur ? _gpmOrange : _gpmText, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(list[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmSub, fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.more_vert, color: _gpmSub, size: 20),
                              onPressed: () => showPlayMusicTrackMenu(context, list[i]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // NEW RELEASES: album grid.
  Widget _buildNewReleasesTab() {
    _newFuture ??= YouTubeMusic.searchAlbums('new album releases ${DateTime.now().year}');
    return FutureBuilder<List<YtAlbum>>(
      future: _newFuture,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _gpmOrange));
        final list = snap.data ?? const <YtAlbum>[];
        if (list.isEmpty) {
          return Center(
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: _gpmOrange),
              onPressed: () => setState(() => _newFuture = YouTubeMusic.searchAlbums('new album releases ${DateTime.now().year}')),
              child: Text(snap.hasError ? 'Couldn\'t load new releases: ${snap.error}\nTAP TO RETRY' : 'TAP TO RETRY', textAlign: TextAlign.center),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.74),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final al = list[i];
            return _gpmSquareCard(
              title: al.title,
              subtitle: al.artist,
              cover: _gpmNetArt(al.thumbnail),
              onTap: () => Navigator.of(context).push(_gpmActivityRoute(RevivedAlbumPage(url: al.url, initialTitle: al.title, initialThumb: al.thumbnail))),
              onPlay: () async {
                try {
                  final t = (await YouTubeMusic.album(al.url)).tracks;
                  if (t.isNotEmpty && mounted) _playList(t, 0);
                } catch (_) {}
              },
              onMore: () => showPlayMusicCollectionMenu(context, title: al.title, subtitle: al.artist, thumbnail: al.thumbnail,
                  artistName: al.artist, load: () async => (await YouTubeMusic.album(al.url)).tracks),
            );
          },
        );
      },
    );
  }

  Widget _buildBrowseBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
          child: Text('Genres & moods', style: TextStyle(color: _gpmText, fontSize: 18, fontWeight: FontWeight.w500)),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.5,
          children: [for (final g in _browseGenres) _browseTile(g)],
        ),
      ],
    );
  }

  // ── INLINE PLAY MUSIC SEARCH ──────────────────────────────────────────────
  List<String> get _searchHistory {
    try {
      final v = jsonDecode(appState.str('gpm_search_history', '[]'));
      if (v is List) return [for (final x in v) x.toString()];
    } catch (_) {}
    return const [];
  }

  void _rememberSearch(String q) {
    final h = [q, ..._searchHistory.where((x) => x.toLowerCase() != q.toLowerCase())].take(12).toList();
    appState.setStr('gpm_search_history', jsonEncode(h));
  }

  Widget _buildSearchBody() {
    if (_searching) return const Center(child: CircularProgressIndicator(color: _gpmOrange));
    if (_searchCtrl.text.trim().isEmpty) {
      final hist = _searchHistory;
      if (hist.isEmpty) {
        return Center(child: Text('Search for artists, albums and songs', style: TextStyle(color: _gpmSub)));
      }
      return Container(
        color: _gpmWhite,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Recent searches', style: TextStyle(color: _gpmSub, fontSize: 13.5, fontWeight: FontWeight.w500))),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _gpmOrange),
                    onPressed: () => appState.setStr('gpm_search_history', '[]'),
                    child: const Text('CLEAR'),
                  ),
                ],
              ),
            ),
            for (final q in hist)
              ListTile(
                leading: Icon(Icons.history, color: _gpmSub),
                title: Text(q, style: TextStyle(color: _gpmText, fontSize: 15)),
                trailing: IconButton(
                  icon: Icon(Icons.north_west, color: _gpmSub, size: 20),
                  onPressed: () => setState(() {
                    _searchCtrl.text = q;
                    _searchCtrl.selection = TextSelection.collapsed(offset: q.length);
                  }),
                ),
                onTap: () => _startSearch(q),
              ),
          ],
        ),
      );
    }
    if (_artistRes.isEmpty && _songRes.isEmpty && _albumRes.isEmpty) {
      return Center(child: Text('No results for "${_searchCtrl.text.trim()}"', style: TextStyle(color: _gpmSub)));
    }
    final topArtist = _artistRes.isNotEmpty ? _artistRes.first : null;
    final topSong = topArtist == null && _songRes.isNotEmpty ? _songRes.first : null;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // Play Music's "Top result" card
        Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 8), child: Text('Top result', style: TextStyle(color: _gpmText, fontSize: 18, fontWeight: FontWeight.w500))),
        Material(
          color: _gpmWhite,
          elevation: 2,
          borderRadius: BorderRadius.circular(2),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              _rememberSearch(_searchCtrl.text.trim());
              if (topArtist != null) {
                Navigator.of(context).push(_gpmActivityRoute(RevivedArtistPage(url: topArtist.url, name: topArtist.name, initialThumb: topArtist.thumbnail)));
              } else if (topSong != null) {
                audioHandler.playYouTubeTrack(topSong);
                _openGpmPlayer(context);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(topArtist != null ? 48 : 0),
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: topArtist != null ? _gpmNetArt(_gpmHiRes(topArtist.thumbnail), size: 96, isArtist: true) : _gpmArt(topSong, size: 96),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(topArtist?.name ?? topSong?.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _gpmText, fontSize: 20, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(topArtist != null ? 'Artist' : 'Song • ${topSong?.artist ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _gpmSub, fontSize: 14)),
                      ],
                    ),
                  ),
                  _gpmOrangeFab(() {
                    if (topArtist != null) {
                      _gpmStartArtistRadio(context, topArtist.name);
                    } else if (topSong != null) {
                      audioHandler.playYouTubeTrack(topSong);
                      _openGpmPlayer(context);
                    }
                  }, size: 44),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_artistRes.length > 1) ...[
          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Artists', style: TextStyle(color: _gpmSub, fontWeight: FontWeight.w600))),
          for (final a in _artistRes.skip(1).take(3))
            Card(
              color: _gpmWhite,
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: SizedBox(width: 46, height: 46, child: _gpmNetArt(a.thumbnail, size: 46, isArtist: true)),
                title: Text(a.name, style: TextStyle(color: _gpmText, fontWeight: FontWeight.w500)),
                subtitle: Text('Artist', style: TextStyle(color: _gpmSub)),
                trailing: IconButton(
                  icon: Icon(Icons.more_vert, color: _gpmSub, size: 20),
                  onPressed: () => showPlayMusicCollectionMenu(context, title: a.name, subtitle: 'Artist', thumbnail: a.thumbnail, isArtist: true,
                      artistName: a.name, load: () async => (await YouTubeMusic.artist(a.url, a.name)).songs),
                ),
                onTap: () => Navigator.of(context).push(_gpmActivityRoute(RevivedArtistPage(url: a.url, name: a.name, initialThumb: a.thumbnail))),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (_songRes.isNotEmpty) ...[
          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Songs', style: TextStyle(color: _gpmSub, fontWeight: FontWeight.w600))),
          for (final t in _songRes.take(10))
            _gpmSongCardRow(t, () {
              audioHandler.playYouTubeTrack(t);
              _openGpmPlayer(context);
            }),
        ],
        if (_albumRes.isNotEmpty) ...[
          Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Albums', style: TextStyle(color: _gpmSub, fontWeight: FontWeight.w600))),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.78,
            children: [
              for (final al in _albumRes.take(6))
                _gpmSquareCard(
                  title: al.title,
                  cover: _gpmNetArt(al.thumbnail),
                  onTap: () => Navigator.of(context).push(_gpmActivityRoute(RevivedAlbumPage(url: al.url, initialTitle: al.title, initialThumb: al.thumbnail))),
                  onPlay: () => Navigator.of(context).push(_gpmActivityRoute(RevivedAlbumPage(url: al.url, initialTitle: al.title, initialThumb: al.thumbnail))),
                  onMore: () => showPlayMusicCollectionMenu(context, title: al.title, subtitle: 'Album', thumbnail: al.thumbnail,
                      load: () async => (await YouTubeMusic.album(al.url)).tracks),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // ── CLASSIC MATERIAL 1 WHITE CARD (Matches 27.png, 28.png, 29.png) ────────
  Widget _gpmSquareCard({
    required String title,
    required Widget cover,
    required VoidCallback onTap,
    required VoidCallback onPlay,
    double aspectRatio = 1.0,
    bool showMore = true,
    IconData badgeIcon = Icons.play_arrow,
    String? subtitle,
    VoidCallback? onMore,
  }) =>
      Material(
        color: _gpmWhite,
        elevation: 2.0,
        shadowColor: const Color(0x44000000),
        borderRadius: BorderRadius.circular(2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashFactory: InkRipple.splashFactory,
          splashColor: _gpmOrange.withOpacity(0.18),
          highlightColor: Colors.black.withOpacity(0.06),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    cover,
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: GestureDetector(
                        onTap: onPlay,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.88), shape: BoxShape.circle),
                          child: Icon(badgeIcon, color: _gpmSub, size: 19),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: (subtitle == null || subtitle.isEmpty)
                            ? Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: _gpmText, fontSize: 14, fontWeight: FontWeight.w400))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: _gpmText, fontSize: 14, fontWeight: FontWeight.w400)),
                                  const SizedBox(height: 2),
                                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: _gpmSub, fontSize: 12.5)),
                                ],
                              ),
                      ),
                      if (showMore)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onMore,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 0, 2, 6),
                            child: Icon(Icons.more_vert, color: _gpmSub, size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // ── CLASSIC WHITE SONG ROW (Matches 30.png) ───────────────────────────────
  Widget _gpmSongCardRow(TrackItem t, VoidCallback onTap) {
    final active = audioHandler.currentTrack?.id == t.id;
    final dur = t.durationSeconds > 0 ? ' • ${formatDuration(Duration(seconds: t.durationSeconds))}' : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: _gpmWhite,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        leading: SizedBox(width: 48, height: 48, child: _gpmArt(t, size: 48)),
        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: active ? _gpmOrange : _gpmText, fontSize: 15, fontWeight: FontWeight.w400)),
        subtitle: Text('${t.artist.isEmpty ? "Unknown artist" : t.artist}$dur', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _gpmSub, fontSize: 12.5)),
        trailing: IconButton(icon: Icon(Icons.more_vert, color: _gpmSub, size: 20), onPressed: () => showPlayMusicTrackMenu(context, t)),
        onTap: onTap,
      ),
    );
  }

  // ── WHITE MINI-PLAYER (sits on top of the bottom tab bar) ────────────────
  Widget _buildDockedMiniPlayer(BuildContext context) {
    final t = audioHandler.currentTrack;
    if (t == null) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openGpmPlayer(context),
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0.0;
        if (v < -250) {
          audioHandler.skipToNext();
        } else if (v > 250) {
          audioHandler.skipToPreviousTrack();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: _gpmWhite,
          boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 6, offset: Offset(0, -1))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<Duration>(
              stream: audioHandler.player.positionStream,
              builder: (_, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = audioHandler.player.duration ?? Duration.zero;
                final frac = dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
                return LinearProgressIndicator(
                  value: frac,
                  minHeight: 2,
                  backgroundColor: _gpmDivider,
                  valueColor: const AlwaysStoppedAnimation(_gpmOrange),
                );
              },
            ),
            SizedBox(
              height: 60,
              child: Row(
                children: [
                  SizedBox(width: 60, height: 60, child: _gpmArt(t, size: 60)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmText, fontSize: 15, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(t.artist.isEmpty ? 'Unknown artist' : t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmSub, fontSize: 13)),
                      ],
                    ),
                  ),
                  StreamBuilder<PlaybackState>(
                    stream: audioHandler.playbackState,
                    builder: (_, snap) {
                      final playing = snap.data?.playing ?? audioHandler.player.playing;
                      return IconButton(
                        iconSize: 34,
                        color: _gpmText,
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. ICONIC GOOGLE PLAY MUSIC NOW PLAYING SCREEN (Exact Match to 33.png!)
// ═════════════════════════════════════════════════════════════════════════════
class RevivedPlayerScreen extends StatefulWidget {
  const RevivedPlayerScreen({super.key});
  @override
  State<RevivedPlayerScreen> createState() => _RevivedPlayerScreenState();
}

class _RevivedPlayerScreenState extends State<RevivedPlayerScreen> {
  double _dragY = 0.0;
  bool _draggingY = false;

  @override
  void initState() {
    super.initState();
    audioHandler.currentIndex.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    audioHandler.currentIndex.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final track = audioHandler.currentTrack;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            onVerticalDragUpdate: (d) {
              if (d.delta.dy < 0 && _dragY <= 0) return;
              setState(() {
                _draggingY = true;
                _dragY = (_dragY + d.delta.dy).clamp(0.0, MediaQuery.of(context).size.height);
              });
            },
            onVerticalDragEnd: (d) {
              if (_dragY > 100 || (d.primaryVelocity ?? 0) > 550) {
                setState(() {
                  _draggingY = false;
                  _dragY = MediaQuery.of(context).size.height;
                });
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (mounted) Navigator.of(context).pop();
                });
              } else {
                setState(() {
                  _draggingY = false;
                  _dragY = 0.0;
                });
              }
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: _draggingY ? 0 : 220),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()..translate(0.0, _dragY),
              color: const Color(0xFFFFFFFF),
              child: track == null
                  ? const Center(
                      child: Text(
                        'Nothing playing',
                        style: TextStyle(color: Color(0xFF757575)),
                      ),
                    )
                  : SafeArea(
                      child: Column(
                        children: [
                          Container(
                            height: 58,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFFFFF),
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFE0E0E0), width: 0.8),
                              ),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: SizedBox(
                                    width: 58,
                                    height: 58,
                                    child: CustomAlbumArtwork(track: track),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF212121),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF757575),
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.queue_music, color: Color(0xFF212121), size: 24),
                                  onPressed: () => _showGpm2018QueueSheet(context),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert, color: Color(0xFF212121), size: 22),
                                  onPressed: () => showPlayMusicTrackMenu(context, track, inPlayer: true),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onHorizontalDragEnd: (d) {
                                final v = d.primaryVelocity ?? 0.0;
                                if (v < -250) {
                                  audioHandler.skipToNext();
                                } else if (v > 250) {
                                  audioHandler.skipToPreviousTrack();
                                }
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CustomAlbumArtwork(track: track),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: 92,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.55),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 8,
                                    right: 8,
                                    bottom: 10,
                                    child: StreamBuilder<PlaybackState>(
                                      stream: audioHandler.playbackState,
                                      builder: (_, snap) {
                                        final st = snap.data ?? audioHandler.playbackState.value;
                                        final shuf = st.shuffleMode == AudioServiceShuffleMode.all;
                                        final rep = st.repeatMode;
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                rep == AudioServiceRepeatMode.one
                                                    ? Icons.repeat_one
                                                    : Icons.repeat,
                                                color: rep == AudioServiceRepeatMode.none
                                                    ? Colors.white
                                                    : const Color(0xFFFF5722),
                                                size: 22,
                                              ),
                                              onPressed: () {
                                                final next = rep == AudioServiceRepeatMode.none
                                                    ? AudioServiceRepeatMode.all
                                                    : (rep == AudioServiceRepeatMode.all
                                                        ? AudioServiceRepeatMode.one
                                                        : AudioServiceRepeatMode.none);
                                                audioHandler.setRepeatMode(next);
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.subtitles_outlined, color: Colors.white, size: 22),
                                              onPressed: () => _showGpm2018LyricsSheet(context, track),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.shuffle,
                                                color: shuf ? const Color(0xFFFF5722) : Colors.white,
                                                size: 22,
                                              ),
                                              onPressed: () => audioHandler.setShuffleMode(
                                                shuf ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          StreamBuilder<Duration>(
                            stream: audioHandler.player.positionStream,
                            builder: (context, snap) {
                              final pos = snap.data ?? Duration.zero;
                              final dur = audioHandler.player.duration ?? Duration(seconds: track.durationSeconds);
                              final maxMs = max(1, dur.inMilliseconds).toDouble();
                              final curMs = pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2.5,
                                      trackShape: const RectangularSliderTrackShape(),
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                      activeTrackColor: const Color(0xFFFF5722),
                                      inactiveTrackColor: const Color(0xFFD6D6D6),
                                      thumbColor: const Color(0xFFFF5722),
                                    ),
                                    child: SizedBox(
                                      height: 20,
                                      child: Slider(
                                        value: curMs,
                                        max: maxMs,
                                        onChanged: (v) => audioHandler.seek(Duration(milliseconds: v.round())),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          formatDuration(pos),
                                          style: const TextStyle(
                                            color: Color(0xFFFF5722),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          formatDuration(dur),
                                          style: const TextStyle(color: Color(0xFF757575), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          Container(
                            color: const Color(0xFFFFFFFF),
                            padding: const EdgeInsets.fromLTRB(10, 4, 10, 14),
                            child: StreamBuilder<PlaybackState>(
                              stream: audioHandler.playbackState,
                              builder: (_, snap) {
                                final playing = snap.data?.playing ?? audioHandler.player.playing;
                                final liked = appState.isLiked(track.id);
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                        color: liked ? const Color(0xFFFF5722) : const Color(0xFF212121),
                                        size: 23,
                                      ),
                                      onPressed: () => appState.toggleLike(track.id),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.skip_previous, color: Color(0xFF212121), size: 30),
                                      onPressed: () => audioHandler.skipToPrevious(),
                                    ),
                                    Material(
                                      color: const Color(0xFFFF5722),
                                      shape: const CircleBorder(),
                                      elevation: 3,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => playing ? audioHandler.pause() : audioHandler.play(),
                                        child: SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: Icon(
                                            playing ? Icons.pause : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.skip_next, color: Color(0xFF212121), size: 30),
                                      onPressed: () => audioHandler.skipToNext(),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.thumb_down_outlined, color: Color(0xFF212121), size: 23),
                                      onPressed: () {
                                        // Play Music: thumbs down removes the thumbs up and skips.
                                        if (appState.isLiked(track.id)) appState.toggleLike(track.id);
                                        audioHandler.skipToNext();
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _EdgeToEdgeTrackShape extends RoundedRectSliderTrackShape {
  const _EdgeToEdgeTrackShape();
  @override
  Rect getPreferredRect({required RenderBox parentBox, Offset offset = Offset.zero, required SliderThemeData sliderTheme, bool isEnabled = false, bool isDiscrete = false}) {
    final h = sliderTheme.trackHeight ?? 3.0;
    return Rect.fromLTWH(0, offset.dy + (parentBox.size.height - h) / 2, parentBox.size.width, h);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. ALBUM, ARTIST & PLAYLIST DETAIL PAGES (Classic Play Music Material 1)
// ═════════════════════════════════════════════════════════════════════════════
class RevivedAlbumPage extends StatefulWidget {
  final String url;
  final String? initialTitle;
  final String? initialThumb;
  const RevivedAlbumPage({super.key, required this.url, this.initialTitle, this.initialThumb});
  @override
  State<RevivedAlbumPage> createState() => _RevivedAlbumPageState();
}

class _RevivedAlbumPageState extends State<RevivedAlbumPage> {
  late Future<YtAlbumPage> _future;
  @override
  void initState() {
    super.initState();
    _future = YouTubeMusic.album(widget.url);
  }

  void _play(YtAlbumPage page, int i) {
    if (page.tracks.isEmpty) return;
    audioHandler.playYouTubeList(page.tracks, i, lockToScope: true);
    _openGpmPlayer(context);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<YtAlbumPage>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _gpmLoadingScaffold(context, widget.initialTitle ?? 'Album');
        }
        final page = snap.data;
        if (page == null) {
          return _gpmLoadingScaffold(context, widget.initialTitle ?? 'Album', error: 'Could not load album');
        }
        final w = MediaQuery.of(context).size.width;
        final heroH = min(w, 440.0);
        final meta = [page.kind, page.year, page.info].whereType<String>().where((x) => x.trim().isNotEmpty).join(' • ');
        final cur = audioHandler.currentTrack?.id;
        return _GpmHeroScaffold(
          title: page.title,
          heroHeight: heroH,
          slivers: [
            SliverToBoxAdapter(
              child: _gpmHeroHeader(
                heroHeight: heroH,
                image: _gpmNetArt(_gpmHiRes(page.thumbnail ?? widget.initialThumb)),
                onPlay: () => _play(page, 0),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 96, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(page.title, style: TextStyle(color: _gpmText, fontSize: 22, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(page.artist, style: TextStyle(color: _gpmSub, fontSize: 15)),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(meta, style: TextStyle(color: _gpmSub, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                child: Material(
                  color: _gpmWhite,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(2),
                  child: Column(
                    children: [
                      for (var i = 0; i < page.tracks.length; i++) ...[
                        if (i > 0) Divider(height: 1, indent: 56, color: _gpmDivider),
                        ListTile(
                          leading: SizedBox(
                            width: 24,
                            child: Center(
                              child: page.tracks[i].id == cur
                                  ? const Icon(Icons.equalizer_rounded, color: _gpmOrange, size: 20)
                                  : Text('${i + 1}', style: TextStyle(color: _gpmSub, fontSize: 14)),
                            ),
                          ),
                          title: Text(page.tracks[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: page.tracks[i].id == cur ? _gpmOrange : _gpmText, fontSize: 15)),
                          subtitle: Text(
                            page.tracks[i].durationSeconds > 0
                                ? '${page.tracks[i].artist} • ${formatDuration(Duration(seconds: page.tracks[i].durationSeconds))}'
                                : page.tracks[i].artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _gpmSub, fontSize: 12.5),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.more_vert, color: _gpmSub, size: 20),
                            onPressed: () => showPlayMusicTrackMenu(context, page.tracks[i]),
                          ),
                          onTap: () => _play(page, i),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class RevivedArtistPage extends StatefulWidget {
  final String url;
  final String name;
  final String? initialThumb;
  const RevivedArtistPage({super.key, required this.url, required this.name, this.initialThumb});
  @override
  State<RevivedArtistPage> createState() => _RevivedArtistPageState();
}

class _RevivedArtistPageState extends State<RevivedArtistPage> {
  late Future<YtArtistPage?> _future;
  bool _showAllSongs = false;
  bool _descOpen = false;

  @override
  void initState() {
    super.initState();
    _future = YouTubeMusic.artist(widget.url, widget.name);
  }

  void _play(YtArtistPage page, int i) {
    if (page.songs.isEmpty) return;
    audioHandler.playYouTubeList(page.songs, i, lockToScope: true);
    _openGpmPlayer(context);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<YtArtistPage?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _gpmLoadingScaffold(context, widget.name);
        }
        final page = snap.data;
        if (page == null) {
          return _gpmLoadingScaffold(context, widget.name, error: 'Could not load artist');
        }
        final img = _gpmHiRes(page.banner ?? page.thumbnail ?? widget.initialThumb);
        final w = MediaQuery.of(context).size.width;
        final heroH = (w * 0.72).clamp(240.0, 360.0);
        final songCount = _showAllSongs ? page.songs.length : min(5, page.songs.length);
        final desc = (page.description ?? '').trim();
        var subs = (page.subscribersText ?? '').trim();
        if (subs.isNotEmpty && !subs.toLowerCase().contains('subscriber')) subs = '$subs subscribers';
        final cur = audioHandler.currentTrack?.id;

        return _GpmHeroScaffold(
          title: page.name,
          heroHeight: heroH,
          slivers: [
            SliverToBoxAdapter(
              child: _gpmHeroHeader(
                heroHeight: heroH,
                image: img != null
                    ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF424242)))
                    : Container(color: const Color(0xFF424242)),
                onPlay: () => _play(page, 0),
                body: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 6),
                      child: Column(
                        children: [
                          Text(page.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _gpmText, fontSize: 24, fontWeight: FontWeight.w500)),
                          if (subs.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(subs, textAlign: TextAlign.center, style: TextStyle(color: _gpmSub, fontSize: 13.5)),
                          ],
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: Text(
                                desc,
                                textAlign: TextAlign.center,
                                maxLines: _descOpen ? null : 3,
                                overflow: _descOpen ? TextOverflow.visible : TextOverflow.ellipsis,
                                style: TextStyle(color: _gpmSub, fontSize: 14, height: 1.45),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: _gpmOrange),
                              onPressed: () => setState(() => _descOpen = !_descOpen),
                              child: Text(_descOpen ? 'READ LESS' : 'READ MORE',
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                            ),
                          ] else
                            const SizedBox(height: 14),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: _gpmDivider),
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (page.songs.isEmpty) return;
                                audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
                                audioHandler.playYouTubeList(page.songs, Random().nextInt(page.songs.length), lockToScope: true);
                                _openGpmPlayer(context);
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.sensors, color: _gpmText, size: 21),
                                  const SizedBox(width: 10),
                                  Text('Radio', style: TextStyle(color: _gpmText, fontSize: 15, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                          Container(width: 1, height: 26, color: _gpmDivider),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (page.songs.isNotEmpty) shareTrack(page.songs.first);
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.share, color: _gpmText, size: 20),
                                  const SizedBox(width: 10),
                                  Text('Share', style: TextStyle(color: _gpmText, fontSize: 15, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (page.songs.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                  child: Material(
                    color: _gpmWhite,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(2),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 14, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('Top songs', style: TextStyle(color: _gpmText, fontSize: 18, fontWeight: FontWeight.w500)),
                              ),
                              if (page.songs.length > 5)
                                Material(
                                  color: _gpmOrange,
                                  borderRadius: BorderRadius.circular(2),
                                  child: InkWell(
                                    onTap: () => setState(() => _showAllSongs = !_showAllSongs),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      child: Text(_showAllSongs ? 'LESS' : 'MORE',
                                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (var i = 0; i < songCount; i++) ...[
                          if (i > 0) Divider(height: 1, indent: 72, color: _gpmDivider),
                          ListTile(
                            leading: SizedBox(width: 44, height: 44, child: _gpmArt(page.songs[i], size: 44)),
                            title: Text(page.songs[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: page.songs[i].id == cur ? _gpmOrange : _gpmText, fontSize: 15)),
                            subtitle: Text(
                              _artistSongSub(page, page.songs[i]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _gpmSub, fontSize: 12.5),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.more_vert, color: _gpmSub, size: 20),
                              onPressed: () => showPlayMusicTrackMenu(context, page.songs[i]),
                            ),
                            onTap: () => _play(page, i),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            for (final sh in page.shelves.where((s) => s.items.isNotEmpty))
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: Material(
                    color: _gpmWhite,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(2),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sh.title.isEmpty ? 'Albums' : sh.title,
                              style: TextStyle(color: _gpmText, fontSize: 18, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: sh.items.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, i) {
                                final it = sh.items[i];
                                final round = it.kind == 'artist';
                                return GestureDetector(
                                  onLongPress: () => gpmShelfItemMenu(context, it),
                                  onTap: () => gpmOpenShelfItem(context, it),
                                  child: SizedBox(
                                    width: 126,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(round ? 63 : 0),
                                          child: SizedBox(width: 126, height: 126, child: _gpmNetArt(it.thumbnail, size: 126, isArtist: round)),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(it.title,
                                            textAlign: round ? TextAlign.center : TextAlign.start,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: _gpmText, fontSize: 13.5, fontWeight: FontWeight.w500)),
                                        Text(it.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: _gpmSub, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // "Periphery • 4:02", or plays ("12M plays") when YouTube gives no length.
  String _artistSongSub(YtArtistPage page, TrackItem t) {
    final parts = <String>[t.artist.isNotEmpty ? t.artist : page.name];
    if (t.durationSeconds > 0) {
      parts.add(formatDuration(Duration(seconds: t.durationSeconds)));
    } else {
      final p = page.plays[t.id] ?? page.plays[t.ytVideoId ?? ''];
      if (p != null && p.isNotEmpty) parts.add(p);
    }
    return parts.join(' • ');
  }
}

class RevivedPlaylistPage extends StatefulWidget {
  final Playlist? localPlaylist;
  final String? ytPlaylistId;
  final String? title;
  final String? subtitle;
  final String? thumbnail;
  final List<TrackItem>? customTracks;

  const RevivedPlaylistPage.local({super.key, required Playlist playlist})
      : localPlaylist = playlist, ytPlaylistId = null, title = null, subtitle = null, thumbnail = null, customTracks = null;

  const RevivedPlaylistPage.youtube({super.key, required String playlistId, this.title, this.thumbnail})
      : localPlaylist = null, ytPlaylistId = playlistId, subtitle = null, customTracks = null;

  const RevivedPlaylistPage.custom({super.key, required this.title, this.subtitle, required List<TrackItem> tracks})
      : localPlaylist = null, ytPlaylistId = null, thumbnail = null, customTracks = tracks;

  @override
  State<RevivedPlaylistPage> createState() => _RevivedPlaylistPageState();
}

class _RevivedPlaylistPageState extends State<RevivedPlaylistPage> {
  Future<YtAlbumPage>? _ytFuture;
  YtAlbumPage? _cached;

  @override
  void initState() {
    super.initState();
    if (widget.ytPlaylistId != null) {
      _cached = widget.ytPlaylistId == 'LM'
          ? (_memLikedPage ?? YouTubeMusic.cachedPlaylistPage('LM', title: 'Thumbs up'))
          : YouTubeMusic.cachedPlaylistPage(widget.ytPlaylistId!, title: widget.title, thumbnail: widget.thumbnail);
      _ytFuture = YouTubeMusic.playlistPage(widget.ytPlaylistId!, title: widget.title, thumbnail: widget.thumbnail);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customTracks != null) return _buildList(widget.title ?? 'Playlist', widget.customTracks!);
    if (widget.localPlaylist != null) {
      final list = widget.localPlaylist!.trackIds.map(audioHandler.trackById).whereType<TrackItem>().toList();
      return _buildList(widget.localPlaylist!.name, list);
    }
    return FutureBuilder<YtAlbumPage>(
      future: _ytFuture,
      initialData: _cached,
      builder: (_, snap) {
        final page = snap.data;
        if (page == null) {
          return Scaffold(
            backgroundColor: _gpmBg,
      bottomNavigationBar: _gpmSecondaryMiniPlayer(context),
            appBar: AppBar(backgroundColor: _gpmWhite, foregroundColor: _gpmText, surfaceTintColor: Colors.transparent, elevation: 2, title: Text(widget.title ?? 'Playlist')),
            body: const Center(child: CircularProgressIndicator(color: _gpmOrange)),
          );
        }
        return _buildList(page.title, page.tracks);
      },
    );
  }

  Widget _buildList(String name, List<TrackItem> tracks) {
    final w = MediaQuery.of(context).size.width;
    final heroH = min(w * 0.8, 380.0);
    final first = tracks.isNotEmpty ? tracks.first : null;
    final thumb = widget.thumbnail ?? first?.artworkUrl;
    final cur = audioHandler.currentTrack?.id;
    final subtitle = widget.subtitle ?? (widget.localPlaylist != null ? 'Playlist' : (widget.ytPlaylistId != null ? 'YouTube Music playlist' : ''));
    final totalSecs = tracks.fold<int>(0, (a, t) => a + t.durationSeconds);
    final meta = [
      '${tracks.length} songs',
      if (totalSecs > 0) '${(totalSecs / 60).round()} min',
    ].join(' • ');
    void play(int i) {
      if (tracks.isEmpty) return;
      audioHandler.playYouTubeList(tracks, i);
      _openGpmPlayer(context);
    }

    return _GpmHeroScaffold(
      title: name,
      heroHeight: heroH,
      actions: (fg) {
        final done = tracks.isNotEmpty && tracks.every(OfflineStore.isDownloaded);
        final sh = fg == Colors.white ? const [Shadow(color: Color(0x99000000), blurRadius: 8)] : null;
        return [
          IconButton(
            tooltip: 'Download',
            icon: Icon(done ? Icons.offline_pin : Icons.file_download, color: done ? _gpmOrange : fg, shadows: sh),
            onPressed: () {
              final yt = tracks.where((t) => t.isYouTube).toList();
              if (yt.isEmpty) return;
              OfflineStore.downloadAll(yt);
              _gpmSnack(context, 'Downloading ${yt.length} songs');
            },
          ),
          IconButton(
            tooltip: 'Shuffle',
            icon: Icon(Icons.shuffle, color: fg, shadows: sh),
            onPressed: () {
              if (tracks.isEmpty) return;
              audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
              play(Random().nextInt(tracks.length));
            },
          ),
        ];
      },
      slivers: [
        SliverToBoxAdapter(
          child: _gpmHeroHeader(
            heroHeight: heroH,
            image: thumb != null && thumb.isNotEmpty
                ? _gpmNetArt(_gpmHiRes(thumb))
                : (first != null ? _gpmArt(first) : _gpmMosaicPlaceholder()),
            onPlay: () => play(0),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 96, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(color: _gpmText, fontSize: 22, fontWeight: FontWeight.w500)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: _gpmSub, fontSize: 15)),
                  ],
                  const SizedBox(height: 4),
                  Text(meta, style: TextStyle(color: _gpmSub, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
        if (tracks.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('No songs yet', style: TextStyle(color: _gpmSub))),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Material(
                color: _gpmWhite,
                elevation: 2,
                borderRadius: BorderRadius.circular(2),
                child: Column(
                  children: [
                    for (var i = 0; i < tracks.length; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 72, color: _gpmDivider),
                      ListTile(
                        leading: SizedBox(width: 44, height: 44, child: _gpmArt(tracks[i], size: 44)),
                        title: Text(tracks[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: tracks[i].id == cur ? _gpmOrange : _gpmText, fontSize: 15)),
                        subtitle: Text(
                          tracks[i].durationSeconds > 0
                              ? '${tracks[i].artist} • ${formatDuration(Duration(seconds: tracks[i].durationSeconds))}'
                              : tracks[i].artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _gpmSub, fontSize: 12.5),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tracks[i].isYouTube && OfflineStore.isDownloaded(tracks[i]))
                              const Icon(Icons.offline_pin, color: _gpmOrange, size: 18),
                            IconButton(
                              icon: Icon(Icons.more_vert, color: _gpmSub, size: 20),
                              onPressed: () => showPlayMusicTrackMenu(context, tracks[i]),
                            ),
                          ],
                        ),
                        onTap: () => play(i),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 5. MUSIC SETTINGS (Exact Match to 32.png!)
// ═════════════════════════════════════════════════════════════════════════════
void openRevivedSettings(BuildContext context) {
  Navigator.of(context).push(_gpmActivityRoute(const RevivedSettingsScreen()));
}

class RevivedSettingsScreen extends StatelessWidget {
  const RevivedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (_gpmDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent),
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => Scaffold(
          backgroundColor: _gpmWhite,
          appBar: AppBar(
            backgroundColor: _gpmWhite,
            foregroundColor: _gpmText,
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            title: Text('Settings', style: TextStyle(color: _gpmText, fontSize: 20, fontWeight: FontWeight.w500)),
          ),
          body: ListView(
            children: [
              _gpmSection('Account'),
              ValueListenableBuilder<YtAccount>(
                valueListenable: ytAccount,
                builder: (_, acc, __) => ListTile(
                  title: Text(acc.signedIn ? (acc.name ?? 'YouTube Music account') : 'Tap to choose account', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                  subtitle: acc.signedIn ? Text('YouTube Music connected', style: TextStyle(color: _gpmSub, fontSize: 13)) : null,
                  onTap: () => showYtAccountSheet(context),
                ),
              ),
              Divider(height: 1, color: _gpmDivider),
              _gpmSection('General'),
              _gpmSwitch('Downloaded only', 'Only show music that\'s on this device', _gpmDownloadedOnly, (v) => appState.setB('gpm_downloaded_only', v)),
              Divider(height: 1, color: _gpmDivider),
              _gpmSwitch('Dark theme', 'Use classic dark Material theme', _gpmDark, (v) => appState.setB('gpm_dark_theme', v)),
              Divider(height: 1, color: _gpmDivider),
              _gpmSection('Downloading & streaming'),
              ListTile(
                title: Text('Import from Spotify', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                onTap: () => openSpotifyImport(context),
              ),
              Divider(height: 1, color: _gpmDivider),
              ListTile(
                title: Text('Offline downloads', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                subtitle: Text('${OfflineStore.count} songs • ${OfflineStore.formatBytes(OfflineStore.totalBytes)}', style: TextStyle(color: _gpmSub, fontSize: 13)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RevivedDownloadsPage())),
              ),
              Divider(height: 1, color: _gpmDivider),
              ListTile(
                title: Text('Clear stream cache', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                onTap: () async {
                  await const MethodChannel('com.alexlmp.app/ytmusic').invokeMethod('ytClearCache');
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), content: Text('Stream cache cleared')));
                },
              ),
              Divider(height: 1, color: _gpmDivider),
              _gpmSection('Playback'),
              ListTile(
                title: Text('Equalizer', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                subtitle: Text('Adjust audio settings', style: TextStyle(color: _gpmSub, fontSize: 13)),
                onTap: () => showPlaybackSheet(context),
              ),
              Divider(height: 1, color: _gpmDivider),
              _gpmSwitch('Crossfade', appState.b('crossfade_on') ? 'Blend songs over ${_gpmCrossfadeSecs()}s' : 'Smoothly blend between songs', appState.b('crossfade_on'), (v) => appState.setB('crossfade_on', v)),
              if (appState.b('crossfade_on'))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Text('Duration: ${_gpmCrossfadeSecs()}s', style: TextStyle(color: _gpmSub, fontSize: 13, fontWeight: FontWeight.w600)),
                      Expanded(
                        child: Slider(
                          activeColor: _gpmOrange,
                          inactiveColor: _gpmDivider,
                          min: 1,
                          max: 12,
                          divisions: 11,
                          value: _gpmCrossfadeSecs().clamp(1, 12).toDouble(),
                          onChanged: (v) => _gpmSetCrossfadeSecs(v.round()),
                        ),
                      ),
                    ],
                  ),
                ),
              Divider(height: 1, color: _gpmDivider),
              _gpmSwitch('Skip silence', 'Trim dead air between tracks', appState.b('skip_silence'), (v) {
                appState.setB('skip_silence', v);
                audioHandler.player.setSkipSilenceEnabled(v);
              }),
              Divider(height: 1, color: _gpmDivider),
              _gpmSwitch('Autoplay radio', 'Keep music playing after queue ends', appState.b('autoplay_radio'), (v) => appState.setB('autoplay_radio', v)),
              Divider(height: 1, color: _gpmDivider),
              _gpmSwitch('Data saver', 'Lower audio bitrate on mobile data', appState.b('yt_data_saver'), (v) {
                appState.setB('yt_data_saver', v);
                applyNativeSettings();
              }),
              Divider(height: 1, color: _gpmDivider),
              _gpmSection('About Play Music'),
              ListTile(
                title: Text('Check for updates', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                subtitle: Text('Version ${const String.fromEnvironment('APP_BUILD_VER', defaultValue: 'v$kAppVersion')}', style: TextStyle(color: _gpmSub, fontSize: 13)),
                onTap: () => checkRevivedUpdate(context, manual: true),
              ),
              Divider(height: 1, color: _gpmDivider),
              ListTile(
                title: Text('Re-run setup', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                onTap: () {
                  appState.setB('setup_done', false);
                  Navigator.of(context).pushAndRemoveUntil(_gpmActivityRoute(const RevivedSetupScreen()), (_) => false);
                },
              ),
              _gpm2017RepoLink(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gpmSection(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(title, style: const TextStyle(color: _gpmOrange, fontSize: 14, fontWeight: FontWeight.w500)),
      );

  Widget _gpmSwitch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => InkWell(
        onTap: () {
          // HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: _gpmText, fontSize: 15.5, fontWeight: FontWeight.w400)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: _gpmSub, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? _gpmOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: value ? _gpmOrange : _gpmSub, width: 2),
                ),
                child: value ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
              ),
            ],
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// 6. FULL-SCREEN 2015 ANDROID IN-APP UPDATER (Manual check only, no notifs)
// ═════════════════════════════════════════════════════════════════════════════
const String _kUpdateRepo = 'cashhwocky/PlayMusicRevived';
const MethodChannel _kRevivedMediaCh = MethodChannel('com.alexlmp.app/media');

Future<void> checkRevivedUpdate(BuildContext context, {bool manual = false}) async {
  if (!manual) return; // Never auto-notify or pop up in the background
  try {
    final res = await http
        .get(
          Uri.parse('https://api.github.com/repos/$_kUpdateRepo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'PlayMusicRevived'},
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), content: Text('No published releases found yet')));
      }
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^[vV]'), '');
    final notes = (data['body'] ?? 'Bug fixes, audio improvements, and classic Play Music updates.').toString().trim();
    String? apkUrl;
    for (final a in (data['assets'] as List? ?? const [])) {
      if (a is Map && (a['name'] ?? '').toString().toLowerCase().contains('universal') && (a['name'] ?? '').toString().toLowerCase().endsWith('.apk')) {
        apkUrl = a['browser_download_url']?.toString();
        break;
      }
    }
    apkUrl ??= (data['assets'] as List? ?? const [])
        .whereType()
        .map((a) => a['browser_download_url']?.toString())
        .firstWhere((u) => u != null && u.toLowerCase().endsWith('.apk'), orElse: () => null);
    if (tag.isEmpty || apkUrl == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), content: Text('No APK asset found in latest release')));
      }
      return;
    }

    const builtRaw = String.fromEnvironment('APP_BUILD_VER', defaultValue: '0.0.0');
    final installed = builtRaw.replaceFirst(RegExp(r'^[vV]'), '');
    bool isNewer(String latest, String current) {
      final a = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final b = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final len = max(a.length, b.length);
      for (var i = 0; i < len; i++) {
        final av = i < a.length ? a[i] : 0;
        final bv = i < b.length ? b[i] : 0;
        if (av != bv) return av > bv;
      }
      return false;
    }

    if (!isNewer(tag, installed)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), content: Text('Play Music Revived is up to date (v$installed)')));
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(_gpmActivityRoute(PlayMusicUpdateScreen(version: tag, notes: notes, apkUrl: apkUrl)));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), content: Text('Could not check for updates right now')));
    }
  }
}

class PlayMusicUpdateScreen extends StatefulWidget {
  final String version;
  final String notes;
  final String apkUrl;
  const PlayMusicUpdateScreen({super.key, required this.version, required this.notes, required this.apkUrl});
  @override
  State<PlayMusicUpdateScreen> createState() => _PlayMusicUpdateScreenState();
}

class _PlayMusicUpdateScreenState extends State<PlayMusicUpdateScreen> {
  bool _downloading = false;
  double _progress = 0;
  String _status = '';

  Future<void> _downloadAndInstall() async {
    // HapticFeedback.lightImpact();
    setState(() {
      _downloading = true;
      _progress = 0;
      _status = 'Downloading update…';
    });
    try {
      final req = http.Request('GET', Uri.parse(widget.apkUrl));
      final streamed = await http.Client().send(req);
      final total = streamed.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/PlayMusicRevived-${widget.version}.apk');
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          final pct = (received / total).clamp(0.0, 1.0);
          setState(() {
            _progress = pct;
            _status = 'Downloading update… ${(pct * 100).round()}%';
          });
        }
      }
      await sink.close();
      if (!mounted) return;
      setState(() => _status = 'Opening Android package installer…');
      await _kRevivedMediaCh.invokeMethod('installApk', {'path': file.path});
      if (mounted) setState(() => _downloading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _status = 'Download failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: _gpmOrangeDark, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: _gpmBg,
        body: Column(
          children: [
            // Classic 2015 Material 1 Orange Update Banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, top + 8, 16, 24),
              decoration: const BoxDecoration(
                color: _gpmOrange,
                boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_downloading)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                          child: const Icon(Icons.system_update, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('App update available',
                                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 3),
                              Text('Play Music Revived v${widget.version}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Release Notes Material 1 Card
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(2, 4, 2, 8),
                    child: Text("WHAT'S NEW",
                        style: TextStyle(color: _gpmOrange, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _gpmWhite,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1.5))],
                    ),
                    child: Text(
                      widget.notes,
                      style: TextStyle(color: _gpmText, fontSize: 14.5, height: 1.5),
                    ),
                  ),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(_status, style: TextStyle(color: _gpmText, fontSize: 13.5, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 8),
                    if (_downloading)
                      LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 5,
                        backgroundColor: _gpmDivider,
                        valueColor: const AlwaysStoppedAnimation<Color>(_gpmOrange),
                      ),
                  ],
                ],
              ),
            ),

            // Classic Android Bottom Wizard Action Bar
            Container(
              decoration: BoxDecoration(
                color: _gpmWhite,
                border: Border(top: BorderSide(color: _gpmDivider, width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: _gpmSub,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _downloading ? null : () => Navigator.of(context).pop(),
                        child: const Text('NOT NOW', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gpmOrange,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _downloading ? null : _downloadAndInstall,
                        child: Text(
                          _downloading ? 'DOWNLOADING…' : 'DOWNLOAD & INSTALL',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
