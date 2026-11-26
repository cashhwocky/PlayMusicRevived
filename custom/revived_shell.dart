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
const Color _gpmOrangeDark = Color(0xFFE64A19);
const Color _gpmBg = Color(0xFFF5F5F5);
const Color _gpmWhite = Color(0xFFFFFFFF);
const Color _gpmText = Color(0xFF212121);
const Color _gpmSub = Color(0xFF757575);
const Color _gpmDivider = Color(0xFFE0E0E0);
const Color _gpmArtBg = Color(0xFFE0E0E0);
const Color _gpmArtCircle = Color(0xFF9E9E9E);

YtAlbumPage? _memLikedPage;

/// Classic Play Music grey placeholder with circular music note icon
Widget _gpmPlaceholder({double iconSize = 42, bool isArtist = false}) => Container(
      color: _gpmArtBg,
      child: Center(
        child: Container(
          width: iconSize * 1.65,
          height: iconSize * 1.65,
          decoration: const BoxDecoration(color: _gpmArtCircle, shape: BoxShape.circle),
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
      decoration: const BoxDecoration(color: _gpmArtCircle, shape: BoxShape.circle),
      child: const Icon(Icons.music_note_rounded, color: _gpmArtBg, size: 22),
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

/// Classic Play Music Orange Brand Mark
class RevivedBrandMark extends StatelessWidget {
  final double size;
  final String variant;
  const RevivedBrandMark({super.key, this.size = 44, this.variant = 'default'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _gpmOrange, borderRadius: BorderRadius.circular(size * 0.24)),
      child: Icon(Icons.headphones_rounded, color: Colors.white, size: size * 0.58),
    );
  }
}

Future<void> _gpmGoToArtist(BuildContext context, TrackItem t) async {
  if (!t.isYouTube) {
    final local = audioHandler.tracks.where((x) => !x.isYouTube && x.artist == t.artist).toList();
    if (local.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedPlaylistPage.custom(title: t.artist, subtitle: 'Artist', tracks: local)));
    }
    return;
  }
  try {
    final links = await YouTubeMusic.trackLinks(t.ytVideoId!);
    if (!context.mounted) return;
    if (links.artistUrl != null && links.artistUrl!.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedArtistPage(url: links.artistUrl!, name: links.artistName ?? t.artist)));
      return;
    }
    final found = await YouTubeMusic.searchArtists(t.artist);
    if (!context.mounted) return;
    if (found.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedArtistPage(url: found.first.url, name: found.first.name, initialThumb: found.first.thumbnail)));
    }
  } catch (_) {}
}

Future<void> _gpmGoToAlbum(BuildContext context, TrackItem t) async {
  if (!t.isYouTube) {
    final local = audioHandler.tracks.where((x) => !x.isYouTube && x.album == t.album).toList();
    if (local.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedPlaylistPage.custom(title: t.album, subtitle: t.artist, tracks: local)));
    }
    return;
  }
  try {
    final links = await YouTubeMusic.trackLinks(t.ytVideoId!);
    if (!context.mounted) return;
    final ref = links.albumBrowseId ?? links.albumUrl;
    if (ref != null && ref.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RevivedAlbumPage(url: ref, initialTitle: links.albumTitle ?? t.album, initialThumb: links.albumThumbnail ?? t.artworkUrl),
      ));
    }
  } catch (_) {}
}

void showPlayMusicTrackMenu(BuildContext context, TrackItem track) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: _gpmWhite,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: SizedBox(width: 44, height: 44, child: _gpmArt(track, size: 44)),
              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmText, fontWeight: FontWeight.w600)),
              subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmSub)),
            ),
            const Divider(height: 1, color: _gpmDivider),
            _gpmMenuTile(Icons.queue_play_next, 'Play next', () {
              audioHandler.addToQueue([track], next: true);
              Navigator.pop(ctx);
            }),
            _gpmMenuTile(Icons.add_to_queue, 'Add to queue', () {
              audioHandler.addToQueue([track]);
              Navigator.pop(ctx);
            }),
            _gpmMenuTile(Icons.playlist_add, 'Add to playlist', () {
              Navigator.pop(ctx);
              track.isYouTube ? showYtAddToPlaylist(context, track) : showAddToPlaylistSheet(context, track);
            }),
            if (track.isYouTube)
              _gpmMenuTile(
                OfflineStore.isDownloaded(track) ? Icons.download_done : Icons.download_outlined,
                OfflineStore.isDownloaded(track) ? 'Remove download' : 'Download',
                () {
                  Navigator.pop(ctx);
                  toggleOffline(track);
                },
              ),
            _gpmMenuTile(Icons.person_outline, 'Go to artist', () {
              Navigator.pop(ctx);
              _gpmGoToArtist(context, track);
            }),
            _gpmMenuTile(Icons.album_outlined, 'Go to album', () {
              Navigator.pop(ctx);
              _gpmGoToAlbum(context, track);
            }),
            _gpmMenuTile(Icons.lyrics_outlined, 'Lyrics', () {
              Navigator.pop(ctx);
              showLyricsSheet(context, track);
            }),
            _gpmMenuTile(Icons.share, 'Share', () {
              Navigator.pop(ctx);
              shareTrack(track);
            }),
          ],
        ),
      ),
    ),
  );
}

Widget _gpmMenuTile(IconData icon, String label, VoidCallback onTap) => ListTile(
      dense: true,
      leading: Icon(icon, color: _gpmSub, size: 22),
      title: Text(label, style: const TextStyle(color: _gpmText, fontSize: 15)),
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
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AlexLmpRoot()));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: _gpmOrangeDark, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: _gpmWhite,
        appBar: AppBar(
          backgroundColor: _gpmOrange,
          elevation: 2,
          title: const Text('Google Play Music', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ),
        body: ValueListenableBuilder<YtAccount>(
          valueListenable: ytAccount,
          builder: (_, acc, __) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const RevivedBrandMark(size: 56),
                  const SizedBox(height: 20),
                  const Text('Welcome to Play Music', style: TextStyle(color: _gpmText, fontSize: 26, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Stream from YouTube Music or play audio files stored on your device in the classic Material 1 Play Music interface.',
                      style: TextStyle(color: _gpmSub, fontSize: 14.5, height: 1.4)),
                  const SizedBox(height: 24),
                  Card(
                    color: _gpmBg,
                    elevation: 1,
                    child: ListTile(
                      leading: Icon(_storageOk ? Icons.check_circle : Icons.folder_open, color: _gpmOrange),
                      title: Text(_storageOk ? 'Storage access granted' : 'Allow local music access', style: const TextStyle(color: _gpmText, fontWeight: FontWeight.w500)),
                      subtitle: const Text('Scan MP3 / FLAC / WAV files on device', style: TextStyle(color: _gpmSub, fontSize: 12.5)),
                      onTap: _storageOk ? null : _grantStorage,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    color: _gpmBg,
                    elevation: 1,
                    child: ListTile(
                      leading: _signingIn
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.2, color: _gpmOrange))
                          : Icon(acc.signedIn ? Icons.check_circle : Icons.account_circle, color: _gpmOrange),
                      title: Text(acc.signedIn ? 'Signed in as ${acc.name ?? "User"}' : 'Sign in to YouTube Music',
                          style: const TextStyle(color: _gpmText, fontWeight: FontWeight.w500)),
                      subtitle: Text(acc.signedIn ? 'Library & playlists connected' : 'Tap to connect Google account',
                          style: const TextStyle(color: _gpmSub, fontSize: 12.5)),
                      onTap: (acc.signedIn || _signingIn) ? null : _signIn,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _gpmOrange, foregroundColor: Colors.white, elevation: 2),
                      onPressed: _finish,
                      child: Text(acc.signedIn ? 'OPEN MUSIC LIBRARY' : 'SKIP FOR NOW', style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.6)),
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

class _RevivedAppShellState extends State<RevivedAppShell> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  int _drawerIndex = 1; // 0 = Listen Now (YTM Home), 1 = Music library (default, matches 27.png)
  bool _searchMode = false;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<TrackItem> _songRes = [];
  List<YtArtist> _artistRes = [];
  List<YtAlbum> _albumRes = [];

  Future<List<YtShelf>>? _ytFeedFuture;
  Future<List<YtPlaylistRef>>? _ytPlFuture;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _ytFeedFuture = YouTubeMusic.homeFeed();
    _ytPlFuture = YouTubeMusic.libraryPlaylists();
    _preloadLiked();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkRevivedUpdate(context));
  }

  Future<void> _preloadLiked() async {
    _memLikedPage ??= YouTubeMusic.cachedPlaylistPage('LM', title: 'Thumbs up');
    try {
      _memLikedPage = await YouTubeMusic.playlistPage('LM', title: 'Thumbs up');
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _tabCtrl.dispose();
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
    openPlayer(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: _gpmOrangeDark, statusBarIconBrightness: Brightness.light),
      child: ListenableBuilder(
        listenable: Listenable.merge([appState, OfflineStore.revision, LibraryStore.revision, audioHandler.currentIndex]),
        builder: (context, _) {
          return Scaffold(
            backgroundColor: _gpmBg,
            drawer: _buildDrawer(context),
            appBar: AppBar(
              backgroundColor: _gpmOrange,
              foregroundColor: Colors.white,
              elevation: 3,
              titleSpacing: _searchMode ? 0 : NavigationToolbar.kMiddleSpacing,
              leading: _searchMode
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => setState(() {
                        _searchMode = false;
                        _searchCtrl.clear();
                        _songRes = [];
                        _artistRes = [];
                        _albumRes = [];
                      }),
                    )
                  : null,
              title: _searchMode
                  ? TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      onSubmitted: _runSearch,
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                      cursorColor: Colors.white,
                      decoration: const InputDecoration(
                        hintText: 'Search music',
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                      ),
                    )
                  : Text(
                      _drawerIndex == 0 ? 'Listen Now' : 'Music library',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
                    ),
              actions: [
                if (_searchMode && _searchCtrl.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearchChanged('');
                    },
                  )
                else if (!_searchMode)
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () => setState(() => _searchMode = true),
                  ),
              ],
              bottom: (!_searchMode && _drawerIndex == 1)
                  ? TabBar(
                      controller: _tabCtrl,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: Colors.white,
                      indicatorWeight: 2.5,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withOpacity(0.80),
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
                      : (_drawerIndex == 0
                          ? _buildListenNowBody()
                          : TabBarView(
                              controller: _tabCtrl,
                              children: [
                                _buildPlaylistsTab(),
                                _buildArtistsTab(),
                                _buildAlbumsTab(),
                                _buildSongsTab(),
                                _buildGenresTab(),
                              ],
                            )),
                ),
                _buildDockedMiniPlayer(context),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── CLASSIC WHITE DRAWER (Matches 26.png) ─────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: _gpmWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  color: _gpmBg,
                  child: Row(
                    children: [
                      const RevivedBrandMark(size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(acc.signedIn ? (acc.name ?? 'YouTube Music') : 'Play Music',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: _gpmText, fontSize: 15, fontWeight: FontWeight.w600)),
                            Text(acc.signedIn ? 'YouTube Music connected' : 'Tap to sign in',
                                style: const TextStyle(color: _gpmSub, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _drawerTile(Icons.home_outlined, 'Listen Now', _drawerIndex == 0, () {
              setState(() {
                _drawerIndex = 0;
                _searchMode = false;
              });
              Navigator.pop(context);
            }),
            _drawerTile(Icons.library_music, 'Music library', _drawerIndex == 1, () {
              setState(() {
                _drawerIndex = 1;
                _searchMode = false;
              });
              Navigator.pop(context);
            }),
            _drawerTile(Icons.download_done, 'Downloads', false, () {
              Navigator.pop(context);
              openDownloads(context);
            }),
            const Divider(color: _gpmDivider, height: 16),
            ListTile(
              title: const Text('Settings', style: TextStyle(color: _gpmText, fontSize: 14.5, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                openRevivedSettings(context);
              },
            ),
            ListTile(
              title: const Text('Help & feedback', style: TextStyle(color: _gpmText, fontSize: 14.5, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                checkRevivedUpdate(context, manual: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, bool selected, VoidCallback onTap) => Container(
        color: selected ? const Color(0xFFEEEEEE) : Colors.transparent,
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
            const Padding(
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
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RevivedPlaylistPage.custom(title: 'Last added', subtitle: '${lastAdded.length} songs', tracks: lastAdded),
                  )),
                  onPlay: () => _playList(lastAdded, 0),
                ),
                _gpmSquareCard(
                  title: 'Thumbs up',
                  cover: _memLikedPage?.tracks.isNotEmpty == true ? _gpmArt(_memLikedPage!.tracks.first) : _gpmMosaicPlaceholder(),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RevivedPlaylistPage.youtube(playlistId: 'LM', title: 'Thumbs up'),
                  )),
                  onPlay: () {
                    final list = _memLikedPage?.tracks ?? const <TrackItem>[];
                    if (list.isNotEmpty) _playList(list, 0);
                  },
                ),
              ],
            ),
            if (ytPls.isNotEmpty || appState.playlists.isNotEmpty) ...[
              const Padding(
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
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedPlaylistPage.local(playlist: pl))),
                      onPlay: () {
                        final list = pl.trackIds.map(audioHandler.trackById).whereType<TrackItem>().toList();
                        _playList(list, 0);
                      },
                    ),
                  for (final ypl in ytPls)
                    _gpmSquareCard(
                      title: ypl.title,
                      cover: _gpmNetArt(ypl.thumbnail),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RevivedPlaylistPage.youtube(playlistId: ypl.playlistId, title: ypl.title, thumbnail: ypl.thumbnail),
                      )),
                      onPlay: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RevivedPlaylistPage.youtube(playlistId: ypl.playlistId, title: ypl.title, thumbnail: ypl.thumbnail),
                      )),
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
    if (list.isEmpty) return const Center(child: Text('No artists in library', style: TextStyle(color: _gpmSub)));

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
          showMore: false,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RevivedPlaylistPage.custom(title: e.key, subtitle: '${e.value.length} songs', tracks: e.value),
          )),
          onPlay: () => _playList(e.value, 0),
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
    if (list.isEmpty) return const Center(child: Text('No albums in library', style: TextStyle(color: _gpmSub)));

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
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RevivedPlaylistPage.custom(title: e.key, subtitle: e.value.first.artist, tracks: e.value),
          )),
          onPlay: () => _playList(e.value, 0),
        );
      },
    );
  }

  // ── TAB 4: SONGS (Matches 30.png) ─────────────────────────────────────────
  Widget _buildSongsTab() {
    final songs = widget.tracks;
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No local songs yet', style: TextStyle(color: _gpmSub, fontSize: 15)),
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
  Widget _buildListenNowBody() {
    return FutureBuilder<List<YtShelf>>(
      future: _ytFeedFuture,
      initialData: YouTubeMusic.cachedHomeFeed(),
      builder: (_, snap) {
        final shelves = snap.data ?? const <YtShelf>[];
        if (shelves.isEmpty && snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _gpmOrange));
        }
        if (shelves.isEmpty) {
          return Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _gpmOrange, foregroundColor: Colors.white),
              onPressed: () => setState(() => _searchMode = true),
              child: const Text('SEARCH YOUTUBE MUSIC'),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          children: [
            for (final shelf in shelves.take(6)) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(shelf.title.isEmpty ? 'Recommended' : shelf.title,
                    style: const TextStyle(color: _gpmText, fontSize: 18, fontWeight: FontWeight.w500)),
              ),
              SizedBox(
                height: 214,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: shelf.items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final it = shelf.items[i];
                    return SizedBox(
                      width: 152,
                      child: _gpmSquareCard(
                        title: it.title,
                        cover: _gpmNetArt(it.thumbnail, isArtist: it.kind == 'artist'),
                        onTap: () {
                          if (it.kind == 'album') {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedAlbumPage(url: it.id, initialTitle: it.title, initialThumb: it.thumbnail)));
                          } else if (it.kind == 'artist') {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedArtistPage(url: it.id, name: it.title, initialThumb: it.thumbnail)));
                          } else if (it.kind == 'playlist') {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedPlaylistPage.youtube(playlistId: it.id, title: it.title, thumbnail: it.thumbnail)));
                          } else {
                            audioHandler.playYouTubeTrack(YouTubeMusic.trackFromShelf(it, it.subtitle));
                            openPlayer(context);
                          }
                        },
                        onPlay: () {
                          if (it.kind == 'song' || it.kind == 'video') {
                            audioHandler.playYouTubeTrack(YouTubeMusic.trackFromShelf(it, it.subtitle));
                            openPlayer(context);
                          } else if (it.kind == 'album') {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedAlbumPage(url: it.id, initialTitle: it.title, initialThumb: it.thumbnail)));
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],
          ],
        );
      },
    );
  }

  // ── INLINE PLAY MUSIC SEARCH ──────────────────────────────────────────────
  Widget _buildSearchBody() {
    if (_searching) return const Center(child: CircularProgressIndicator(color: _gpmOrange));
    if (_artistRes.isEmpty && _songRes.isEmpty && _albumRes.isEmpty) {
      return const Center(child: Text('Search YouTube Music & local library', style: TextStyle(color: _gpmSub)));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_artistRes.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Artists', style: TextStyle(color: _gpmSub, fontWeight: FontWeight.w600))),
          for (final a in _artistRes.take(2))
            Card(
              color: _gpmWhite,
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: SizedBox(width: 46, height: 46, child: _gpmNetArt(a.thumbnail, size: 46, isArtist: true)),
                title: Text(a.name, style: const TextStyle(color: _gpmText, fontWeight: FontWeight.w500)),
                subtitle: const Text('Artist', style: TextStyle(color: _gpmSub)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedArtistPage(url: a.url, name: a.name, initialThumb: a.thumbnail))),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (_songRes.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Songs', style: TextStyle(color: _gpmSub, fontWeight: FontWeight.w600))),
          for (final t in _songRes.take(10))
            _gpmSongCardRow(t, () {
              audioHandler.playYouTubeTrack(t);
              openPlayer(context);
            }),
        ],
        if (_albumRes.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Albums', style: TextStyle(color: _gpmSub, fontWeight: FontWeight.w600))),
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
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedAlbumPage(url: al.url, initialTitle: al.title, initialThumb: al.thumbnail))),
                  onPlay: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RevivedAlbumPage(url: al.url, initialTitle: al.title, initialThumb: al.thumbnail))),
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
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _gpmWhite,
            borderRadius: BorderRadius.circular(2),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 3, offset: Offset(0, 1.5))],
          ),
          clipBehavior: Clip.antiAlias,
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
                        child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _gpmText, fontSize: 14, fontWeight: FontWeight.w400)),
                      ),
                      if (showMore) const Icon(Icons.more_vert, color: _gpmSub, size: 18),
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
      decoration: const BoxDecoration(
        color: _gpmWhite,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        leading: SizedBox(width: 48, height: 48, child: _gpmArt(t, size: 48)),
        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: active ? _gpmOrange : _gpmText, fontSize: 15, fontWeight: FontWeight.w400)),
        subtitle: Text('${t.artist.isEmpty ? "Unknown artist" : t.artist}$dur', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _gpmSub, fontSize: 12.5)),
        trailing: IconButton(icon: const Icon(Icons.more_vert, color: _gpmSub, size: 20), onPressed: () => showPlayMusicTrackMenu(context, t)),
        onTap: onTap,
      ),
    );
  }

  // ── CLASSIC WHITE DOCKED MINI-PLAYER (Matches 27.png - 31.png) ────────────
  Widget _buildDockedMiniPlayer(BuildContext context) {
    final t = audioHandler.currentTrack;
    if (t == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => openPlayer(context),
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -250) openPlayer(context);
      },
      child: Container(
        decoration: const BoxDecoration(
          color: _gpmWhite,
          boxShadow: [BoxShadow(color: Color(0x24000000), blurRadius: 6, offset: Offset(0, -1))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                const SizedBox(width: 8),
                SizedBox(width: 46, height: 46, child: _gpmArt(t, size: 46)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmText, fontSize: 15, fontWeight: FontWeight.w400)),
                      const SizedBox(height: 1),
                      Text(t.artist.isEmpty ? 'Unknown artist' : t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmSub, fontSize: 12.5)),
                    ],
                  ),
                ),
                StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (_, snap) {
                    final playing = snap.data?.playing ?? audioHandler.player.playing;
                    return IconButton(
                      iconSize: 34,
                      color: Colors.black,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
                    );
                  },
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
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
    final track = audioHandler.currentTrack;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: _gpmOrangeDark, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: _gpmWhite,
        body: track == null
            ? const Center(child: Text('Nothing playing', style: TextStyle(color: _gpmSub)))
            : GestureDetector(
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 450) Navigator.of(context).pop();
                },
                child: Column(
                  children: [
                    // Status bar orange band
                    Container(height: MediaQuery.of(context).padding.top, color: _gpmOrangeDark),
                    // White top header bar (art + title/artist + queue + more)
                    Container(
                      height: 62,
                      color: _gpmWhite,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: SizedBox(width: 44, height: 44, child: _gpmArt(track, size: 44)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.of(context).pop(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmText, fontSize: 15.5, fontWeight: FontWeight.w400)),
                                  const SizedBox(height: 1),
                                  Text(track.artist.isEmpty ? 'Unknown artist' : track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmSub, fontSize: 12.5)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.queue_music, color: _gpmText, size: 24),
                            onPressed: () => _showGpmQueueSheet(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert, color: _gpmSub, size: 24),
                            onPressed: () => showPlayMusicTrackMenu(context, track),
                          ),
                        ],
                      ),
                    ),
                    // Giant edge-to-edge album artwork + bottom-left Repeat & bottom-right Shuffle
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _gpmArt(track),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 90,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.32)],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 14,
                            child: StreamBuilder<PlaybackState>(
                              stream: audioHandler.playbackState,
                              builder: (_, snap) {
                                final st = snap.data ?? audioHandler.playbackState.value;
                                final rep = st.repeatMode;
                                final shuf = st.shuffleMode == AudioServiceShuffleMode.all;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: Icon(rep == AudioServiceRepeatMode.one ? Icons.repeat_one : Icons.repeat,
                                          color: rep == AudioServiceRepeatMode.none ? Colors.white.withOpacity(0.85) : _gpmOrange, size: 24),
                                      onPressed: () {
                                        final next = rep == AudioServiceRepeatMode.none
                                            ? AudioServiceRepeatMode.all
                                            : (rep == AudioServiceRepeatMode.all ? AudioServiceRepeatMode.one : AudioServiceRepeatMode.none);
                                        audioHandler.setRepeatMode(next);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.shuffle, color: shuf ? _gpmOrange : Colors.white.withOpacity(0.85), size: 24),
                                      onPressed: () => audioHandler.setShuffleMode(shuf ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edge-to-edge #FF5722 orange seekbar + white bottom transport dock
                    StreamBuilder<Duration>(
                      stream: audioHandler.player.positionStream,
                      builder: (context, snap) {
                        final pos = snap.data ?? Duration.zero;
                        final dur = audioHandler.player.duration ?? Duration(seconds: track.durationSeconds);
                        final maxMs = max(1, dur.inMilliseconds).toDouble();
                        final curMs = pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
                        return Container(
                          color: _gpmWhite,
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 16,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3.0,
                                      trackShape: const _EdgeToEdgeTrackShape(),
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                      activeTrackColor: _gpmOrange,
                                      inactiveTrackColor: const Color(0xFFD6D6D6),
                                      thumbColor: _gpmOrange,
                                    ),
                                    child: Slider(value: curMs, max: maxMs, onChanged: (v) => audioHandler.seek(Duration(milliseconds: v.round()))),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(formatDuration(pos), style: const TextStyle(color: _gpmSub, fontSize: 12)),
                                      Text(formatDuration(dur), style: const TextStyle(color: _gpmSub, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
                                  child: StreamBuilder<PlaybackState>(
                                    stream: audioHandler.playbackState,
                                    builder: (_, pbSnap) {
                                      final playing = pbSnap.data?.playing ?? audioHandler.player.playing;
                                      return ListenableBuilder(
                                        listenable: appState,
                                        builder: (_, __) {
                                          final liked = appState.isLiked(track.id);
                                          return Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              IconButton(
                                                icon: Icon(liked ? Icons.thumb_up : Icons.thumb_up_off_alt, color: liked ? _gpmOrange : _gpmText, size: 24),
                                                onPressed: () => appState.toggleLike(track.id),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.skip_previous, color: _gpmText, size: 30),
                                                onPressed: () => audioHandler.skipToPrevious(),
                                              ),
                                              GestureDetector(
                                                onTap: () => playing ? audioHandler.pause() : audioHandler.play(),
                                                child: Container(
                                                  width: 56,
                                                  height: 56,
                                                  decoration: const BoxDecoration(
                                                    color: _gpmOrange,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
                                                  ),
                                                  child: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.skip_next, color: _gpmText, size: 30),
                                                onPressed: () => audioHandler.skipToNext(),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.thumb_down_off_alt, color: _gpmText, size: 24),
                                                onPressed: () {
                                                  audioHandler.skipToNext();
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skipped track')));
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showGpmQueueSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _gpmWhite,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, sc) {
          final list = audioHandler.tracks;
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Queue', style: TextStyle(color: _gpmText, fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              const Divider(height: 1, color: _gpmDivider),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final t = list[i];
                    final active = audioHandler.currentTrack?.id == t.id;
                    return ListTile(
                      leading: SizedBox(width: 42, height: 42, child: _gpmArt(t, size: 42)),
                      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _gpmOrange : _gpmText)),
                      subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmSub)),
                      onTap: () {
                        audioHandler.playIndex(i);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gpmBg,
      appBar: AppBar(backgroundColor: _gpmOrange, foregroundColor: Colors.white, title: Text(widget.initialTitle ?? 'Album')),
      body: FutureBuilder<YtAlbumPage>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _gpmOrange));
          final page = snap.data;
          if (page == null) return const Center(child: Text('Could not load album', style: TextStyle(color: _gpmSub)));
          return ListView(
            children: [
              Container(
                color: _gpmWhite,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(width: 112, height: 112, child: _gpmNetArt(page.thumbnail ?? widget.initialThumb, size: 112)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(page.title, style: const TextStyle(color: _gpmText, fontSize: 19, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(page.artist, style: const TextStyle(color: _gpmSub, fontSize: 14)),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: _gpmOrange, foregroundColor: Colors.white),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('PLAY'),
                            onPressed: () {
                              if (page.tracks.isEmpty) return;
                              audioHandler.playYouTubeList(page.tracks, 0, lockToScope: true);
                              openPlayer(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < page.tracks.length; i++)
                Container(
                  color: _gpmWhite,
                  child: ListTile(
                    leading: Text('${i + 1}', style: const TextStyle(color: _gpmSub, fontSize: 14)),
                    title: Text(page.tracks[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmText)),
                    subtitle: Text(page.tracks[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmSub, fontSize: 12.5)),
                    trailing: IconButton(icon: const Icon(Icons.more_vert, color: _gpmSub), onPressed: () => showPlayMusicTrackMenu(context, page.tracks[i])),
                    onTap: () {
                      audioHandler.playYouTubeList(page.tracks, i, lockToScope: true);
                      openPlayer(context);
                    },
                  ),
                ),
            ],
          );
        },
      ),
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
  late Future<YtArtistPage> _future;
  @override
  void initState() {
    super.initState();
    _future = YouTubeMusic.artist(widget.url, widget.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gpmBg,
      appBar: AppBar(backgroundColor: _gpmOrange, foregroundColor: Colors.white, title: Text(widget.name)),
      body: FutureBuilder<YtArtistPage>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _gpmOrange));
          final page = snap.data;
          if (page == null) return const Center(child: Text('Could not load artist', style: TextStyle(color: _gpmSub)));
          return ListView(
            children: [
              SizedBox(height: 190, width: double.infinity, child: _gpmNetArt(page.banner ?? page.thumbnail ?? widget.initialThumb, isArtist: true)),
              Container(
                color: _gpmWhite,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(page.name, style: const TextStyle(color: _gpmText, fontSize: 22, fontWeight: FontWeight.w500)),
                          if (page.subscribersText != null) Text(page.subscribersText!, style: const TextStyle(color: _gpmSub, fontSize: 13)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _gpmOrange, foregroundColor: Colors.white),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('PLAY'),
                      onPressed: () {
                        if (page.songs.isEmpty) return;
                        audioHandler.playYouTubeList(page.songs, 0, lockToScope: true);
                        openPlayer(context);
                      },
                    ),
                  ],
                ),
              ),
              const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Top songs', style: TextStyle(color: _gpmSub, fontWeight: FontWeight.w600))),
              for (var i = 0; i < min(10, page.songs.length); i++)
                Container(
                  color: _gpmWhite,
                  child: ListTile(
                    leading: SizedBox(width: 44, height: 44, child: _gpmArt(page.songs[i], size: 44)),
                    title: Text(page.songs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmText)),
                    subtitle: Text(page.plays[page.songs[i].id] ?? page.songs[i].artist, style: const TextStyle(color: _gpmSub, fontSize: 12.5)),
                    trailing: IconButton(icon: const Icon(Icons.more_vert, color: _gpmSub), onPressed: () => showPlayMusicTrackMenu(context, page.songs[i])),
                    onTap: () {
                      audioHandler.playYouTubeList(page.songs, i, lockToScope: true);
                      openPlayer(context);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
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
            appBar: AppBar(backgroundColor: _gpmOrange, foregroundColor: Colors.white, title: Text(widget.title ?? 'Playlist')),
            body: const Center(child: CircularProgressIndicator(color: _gpmOrange)),
          );
        }
        return _buildList(page.title, page.tracks);
      },
    );
  }

  Widget _buildList(String name, List<TrackItem> tracks) => Scaffold(
        backgroundColor: _gpmBg,
        appBar: AppBar(
          backgroundColor: _gpmOrange,
          foregroundColor: Colors.white,
          title: Text(name),
          actions: [
            IconButton(
              icon: const Icon(Icons.shuffle),
              onPressed: () {
                if (tracks.isEmpty) return;
                audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
                audioHandler.playYouTubeList(tracks, Random().nextInt(tracks.length));
                openPlayer(context);
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: _gpmOrange,
          foregroundColor: Colors.white,
          onPressed: () {
            if (tracks.isEmpty) return;
            audioHandler.playYouTubeList(tracks, 0);
            openPlayer(context);
          },
          child: const Icon(Icons.play_arrow, size: 30),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.only(bottom: 84),
          itemCount: tracks.length,
          itemBuilder: (_, i) {
            final t = tracks[i];
            return Container(
              color: _gpmWhite,
              child: ListTile(
                leading: SizedBox(width: 44, height: 44, child: _gpmArt(t, size: 44)),
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmText)),
                subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gpmSub, fontSize: 12.5)),
                trailing: IconButton(icon: const Icon(Icons.more_vert, color: _gpmSub), onPressed: () => showPlayMusicTrackMenu(context, t)),
                onTap: () {
                  audioHandler.playYouTubeList(tracks, i);
                  openPlayer(context);
                },
              ),
            );
          },
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// 5. MUSIC SETTINGS (Exact Match to 32.png!)
// ═════════════════════════════════════════════════════════════════════════════
void openRevivedSettings(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RevivedSettingsScreen()));
}

class RevivedSettingsScreen extends StatelessWidget {
  const RevivedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: _gpmOrangeDark, statusBarIconBrightness: Brightness.light),
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          appBar: AppBar(
            backgroundColor: _gpmOrange,
            foregroundColor: Colors.white,
            elevation: 2,
            title: const Text('Music settings', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
          ),
          body: ListView(
            children: [
              _gpmSection('ACCOUNT'),
              ValueListenableBuilder<YtAccount>(
                valueListenable: ytAccount,
                builder: (_, acc, __) => ListTile(
                  title: Text(acc.signedIn ? (acc.name ?? 'YouTube Music account') : 'Tap to choose account', style: const TextStyle(color: _gpmText, fontSize: 15.5)),
                  subtitle: acc.signedIn ? const Text('YouTube Music connected', style: TextStyle(color: _gpmSub, fontSize: 13)) : null,
                  onTap: () => showYtAccountSheet(context),
                ),
              ),
              const Divider(height: 1, color: _gpmDivider),
              _gpmSection('LIBRARY & STREAMING'),
              ListTile(
                title: const Text('Import from Spotify', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                onTap: () => openSpotifyImport(context),
              ),
              const Divider(height: 1, color: _gpmDivider),
              ListTile(
                title: const Text('Offline downloads', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                subtitle: Text('${OfflineStore.count} songs • ${OfflineStore.formatBytes(OfflineStore.totalBytes)}', style: const TextStyle(color: _gpmSub, fontSize: 13)),
                onTap: () => openDownloads(context),
              ),
              const Divider(height: 1, color: _gpmDivider),
              ListTile(
                title: const Text('Clear stream cache', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                onTap: () async {
                  await const MethodChannel('com.alexlmp.app/ytmusic').invokeMethod('ytClearCache');
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stream cache cleared')));
                },
              ),
              const Divider(height: 1, color: _gpmDivider),
              _gpmSection('PLAYBACK'),
              ListTile(
                title: const Text('Equalizer', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                subtitle: const Text('Adjust audio settings', style: TextStyle(color: _gpmSub, fontSize: 13)),
                onTap: () => showPlaybackSheet(context),
              ),
              const Divider(height: 1, color: _gpmDivider),
              _gpmSwitch('Crossfade', 'Smoothly blend between songs', appState.b('crossfade_on'), (v) => appState.setB('crossfade_on', v)),
              const Divider(height: 1, color: _gpmDivider),
              _gpmSwitch('Skip silence', 'Trim dead air between tracks', appState.b('skip_silence'), (v) {
                appState.setB('skip_silence', v);
                audioHandler.player.setSkipSilenceEnabled(v);
              }),
              const Divider(height: 1, color: _gpmDivider),
              _gpmSwitch('Autoplay radio', 'Keep music playing after queue ends', appState.b('autoplay_radio'), (v) => appState.setB('autoplay_radio', v)),
              const Divider(height: 1, color: _gpmDivider),
              _gpmSwitch('Data saver', 'Lower audio bitrate on mobile data', appState.b('yt_data_saver'), (v) {
                appState.setB('yt_data_saver', v);
                applyNativeSettings();
              }),
              const Divider(height: 1, color: _gpmDivider),
              _gpmSection('ABOUT PLAY MUSIC'),
              ListTile(
                title: const Text('Check for updates', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                subtitle: const Text(String.fromEnvironment('APP_BUILD_VER', defaultValue: 'v1.0.0'), style: TextStyle(color: _gpmSub, fontSize: 13)),
                onTap: () => checkRevivedUpdate(context, manual: true),
              ),
              const Divider(height: 1, color: _gpmDivider),
              ListTile(
                title: const Text('Re-run setup', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                onTap: () {
                  appState.setB('setup_done', false);
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const RevivedSetupScreen()), (_) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gpmSection(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(title, style: const TextStyle(color: _gpmOrange, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      );

  Widget _gpmSwitch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
        activeColor: _gpmOrange,
        activeTrackColor: _gpmOrange.withOpacity(0.45),
        title: Text(title, style: const TextStyle(color: _gpmText, fontSize: 15.5)),
        subtitle: Text(subtitle, style: const TextStyle(color: _gpmSub, fontSize: 13)),
        value: value,
        onChanged: onChanged,
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// 6. OTA UPDATE CHECKER (cashhwocky/PlayMusicRevived)
// ═════════════════════════════════════════════════════════════════════════════
const String _kUpdateRepo = 'cashhwocky/PlayMusicRevived';
const MethodChannel _kRevivedMediaCh = MethodChannel('com.alexlmp.app/media');

Future<void> checkRevivedUpdate(BuildContext context, {bool manual = false}) async {
  try {
    final res = await http
        .get(Uri.parse('https://api.github.com/repos/$_kUpdateRepo/releases/latest'), headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'PlayMusicRevived'})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      if (manual && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No published releases yet')));
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^[vV]'), '');
    String? apkUrl;
    for (final a in (data['assets'] as List? ?? const [])) {
      if (a is Map && (a['name'] ?? '').toString().toLowerCase().endsWith('.apk')) {
        apkUrl = a['browser_download_url']?.toString();
        break;
      }
    }
    if (tag.isEmpty || apkUrl == null) return;
    const builtRaw = String.fromEnvironment('APP_BUILD_VER', defaultValue: '0.0.0');
    final installed = builtRaw.replaceFirst(RegExp(r'^[vV]'), '');
    if (tag == installed) {
      if (manual && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Already on v$installed')));
      return;
    }
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update available (v$tag)'),
        content: Text((data['body'] ?? 'New Play Music Revived release available.').toString()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('LATER', style: TextStyle(color: _gpmSub))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final req = await http.Client().send(http.Request('GET', Uri.parse(apkUrl!)));
              final dir = await getTemporaryDirectory();
              final file = File('${dir.path}/PlayMusicRevived-$tag.apk');
              final sink = file.openWrite();
              await for (final c in req.stream) {
                sink.add(c);
              }
              await sink.close();
              await _kRevivedMediaCh.invokeMethod('installApk', {'path': file.path});
            },
            child: const Text('UPDATE', style: TextStyle(color: _gpmOrange, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  } catch (_) {}
}
