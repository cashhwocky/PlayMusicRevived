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
Widget _gpm2017RepoLink(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    child: Material(
      color: _gpmCard,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: _gpmDivider, width: 1),
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
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const RevivedPlayerScreen(),
      transitionsBuilder: (_, anim, __, child) {
        final forward = CurvedAnimation(parent: anim, curve: Curves.fastOutSlowIn);
        final reverse = CurvedAnimation(parent: anim, curve: Curves.easeInCubic);
        final activeCurve = anim.status == AnimationStatus.reverse ? reverse : forward;
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(activeCurve),
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
              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmText, fontWeight: FontWeight.w600)),
              subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmSub)),
            ),
            Divider(height: 1, color: _gpmDivider),
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
      title: Text(label, style: TextStyle(color: _gpmText, fontSize: 15)),
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

class _RevivedAppShellState extends State<RevivedAppShell> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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

  bool _backgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabCtrl = TabController(length: 5, vsync: this);
    _ytFeedFuture = YouTubeMusic.homeFeed();
    _ytPlFuture = YouTubeMusic.libraryPlaylists();
    _preloadLiked();
    appState.setB('update_check', false);
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
    _openGpmPlayer(context);
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
              scrolledUnderElevation: 3,
              shadowColor: const Color(0x33000000),
              shape: const Border(),
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
                      dividerColor: Colors.transparent,
                      dividerHeight: 0,
                      controller: _tabCtrl,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: Colors.white,
                      indicatorWeight: 3.0,
                      splashFactory: InkRipple.splashFactory,
                      overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.24)),
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
                                style: TextStyle(color: _gpmText, fontSize: 15, fontWeight: FontWeight.w600)),
                            Text(acc.signedIn ? 'YouTube Music connected' : 'Tap to sign in',
                                style: TextStyle(color: _gpmSub, fontSize: 12)),
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
            Divider(color: _gpmDivider, height: 16),
            ListTile(
              title: Text('Settings', style: TextStyle(color: _gpmText, fontSize: 14.5, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                openRevivedSettings(context);
              },
            ),
            ListTile(
              title: Text('Help & feedback', style: TextStyle(color: _gpmText, fontSize: 14.5, fontWeight: FontWeight.w500)),
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
                ),
                _gpmSquareCard(
                  title: 'Thumbs up',
                  cover: _memLikedPage?.tracks.isNotEmpty == true ? _gpmArt(_memLikedPage!.tracks.first) : _gpmMosaicPlaceholder(),
                  onTap: () => Navigator.of(context).push(_gpmActivityRoute(const RevivedPlaylistPage.youtube(playlistId: 'LM', title: 'Thumbs up'))),
                  onPlay: () {
                    final list = _memLikedPage?.tracks ?? const <TrackItem>[];
                    if (list.isNotEmpty) _playList(list, 0);
                  },
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
                    ),
                  for (final ypl in ytPls)
                    _gpmSquareCard(
                      title: ypl.title,
                      cover: _gpmNetArt(ypl.thumbnail),
                      onTap: () => Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.youtube(playlistId: ypl.playlistId, title: ypl.title, thumbnail: ypl.thumbnail))),
                      onPlay: () => Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.youtube(playlistId: ypl.playlistId, title: ypl.title, thumbnail: ypl.thumbnail))),
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
          showMore: false,
          onTap: () => Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.custom(title: e.key, subtitle: '${e.value.length} songs', tracks: e.value))),
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
          onTap: () => Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.custom(title: e.key, subtitle: e.value.first.artist, tracks: e.value))),
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
                    style: TextStyle(color: _gpmText, fontSize: 18, fontWeight: FontWeight.w500)),
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
                            Navigator.of(context).push(_gpmActivityRoute(RevivedAlbumPage(url: it.id, initialTitle: it.title, initialThumb: it.thumbnail)));
                          } else if (it.kind == 'artist') {
                            Navigator.of(context).push(_gpmActivityRoute(RevivedArtistPage(url: it.id, name: it.title, initialThumb: it.thumbnail)));
                          } else if (it.kind == 'playlist') {
                            Navigator.of(context).push(_gpmActivityRoute(RevivedPlaylistPage.youtube(playlistId: it.id, title: it.title, thumbnail: it.thumbnail)));
                          } else {
                            audioHandler.playYouTubeTrack(YouTubeMusic.trackFromShelf(it, it.subtitle));
                            _openGpmPlayer(context);
                          }
                        },
                        onPlay: () {
                          if (it.kind == 'song' || it.kind == 'video') {
                            audioHandler.playYouTubeTrack(YouTubeMusic.trackFromShelf(it, it.subtitle));
                            _openGpmPlayer(context);
                          } else if (it.kind == 'album') {
                            Navigator.of(context).push(_gpmActivityRoute(RevivedAlbumPage(url: it.id, initialTitle: it.title, initialThumb: it.thumbnail)));
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
      return Center(child: Text('Search YouTube Music & local library', style: TextStyle(color: _gpmSub)));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_artistRes.isNotEmpty) ...[
          Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Artists', style: TextStyle(color: _gpmSub, fontWeight: FontWeight.w600))),
          for (final a in _artistRes.take(2))
            Card(
              color: _gpmWhite,
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: SizedBox(width: 46, height: 46, child: _gpmNetArt(a.thumbnail, size: 46, isArtist: true)),
                title: Text(a.name, style: TextStyle(color: _gpmText, fontWeight: FontWeight.w500)),
                subtitle: Text('Artist', style: TextStyle(color: _gpmSub)),
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
                        child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _gpmText, fontSize: 14, fontWeight: FontWeight.w400)),
                      ),
                      if (showMore) Icon(Icons.more_vert, color: _gpmSub, size: 18),
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

  // ── CLASSIC WHITE DOCKED MINI-PLAYER (Matches 27.png - 31.png) ────────────
  Widget _buildDockedMiniPlayer(BuildContext context) {
    final t = audioHandler.currentTrack;
    if (t == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => openPlayer(context),
      
      child: Container(
        decoration: BoxDecoration(
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
                      Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmText, fontSize: 15, fontWeight: FontWeight.w400)),
                      const SizedBox(height: 1),
                      Text(t.artist.isEmpty ? 'Unknown artist' : t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmSub, fontSize: 12.5)),
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
  bool _dragging = false;

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

  void _onDragUpdate(DragUpdateDetails d) {
    if (d.delta.dy < 0 && _dragY <= 0) return;
    setState(() {
      _dragging = true;
      _dragY = (_dragY + d.delta.dy).clamp(0.0, 640.0);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dragY > 130 || (d.primaryVelocity ?? 0) > 550) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragging = false;
        _dragY = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = audioHandler.currentTrack;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: _gpmOrangeDark, statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: track == null
            ? ColoredBox(color: _gpmWhite, child: Center(child: Text('Nothing playing', style: TextStyle(color: _gpmSub))))
            : GestureDetector(
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: _dragging ? 0 : 240),
                  curve: Curves.fastOutSlowIn,
                  transform: Matrix4.translationValues(0.0, _dragY, 0.0),
                  color: _gpmWhite,
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
                                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmText, fontSize: 15.5, fontWeight: FontWeight.w400)),
                                  const SizedBox(height: 1),
                                  Text(track.artist.isEmpty ? 'Unknown artist' : track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmSub, fontSize: 12.5)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.queue_music, color: _gpmText, size: 24),
                            onPressed: () => _showGpmQueueSheet(context),
                          ),
                          IconButton(
                            icon: Icon(Icons.more_vert, color: _gpmSub, size: 24),
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
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            layoutBuilder: (cur, prev) => Stack(fit: StackFit.expand, children: [...prev, if (cur != null) cur]),
                            child: KeyedSubtree(key: ValueKey(track.id), child: _gpmArt(track)),
                          ),
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
                                      inactiveTrackColor: _gpmDark ? const Color(0xFF4A4A4A) : const Color(0xFFD6D6D6),
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
                                      Text(formatDuration(pos), style: TextStyle(color: _gpmSub, fontSize: 12)),
                                      Text(formatDuration(dur), style: TextStyle(color: _gpmSub, fontSize: 12)),
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
                                                icon: AnimatedScale(
                                                  scale: liked ? 1.18 : 1.0,
                                                  duration: const Duration(milliseconds: 220),
                                                  curve: Curves.easeOutBack,
                                                  child: Icon(liked ? Icons.thumb_up : Icons.thumb_up_off_alt, color: liked ? _gpmOrange : _gpmText, size: 24),
                                                ),
                                                onPressed: () {
                                                  // HapticFeedback.lightImpact();
                                                  appState.toggleLike(track.id);
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.skip_previous, color: _gpmText, size: 30),
                                                onPressed: () => audioHandler.skipToPrevious(),
                                              ),
                                              Material(
                                                color: _gpmOrange,
                                                elevation: 4,
                                                shape: const CircleBorder(),
                                                clipBehavior: Clip.antiAlias,
                                                child: InkWell(
                                                  splashFactory: InkRipple.splashFactory,
                                                  splashColor: Colors.white38,
                                                  onTap: () {
                                                    // HapticFeedback.lightImpact();
                                                    playing ? audioHandler.pause() : audioHandler.play();
                                                  },
                                                  child: SizedBox(
                                                    width: 56,
                                                    height: 56,
                                                    child: AnimatedSwitcher(
                                                      duration: const Duration(milliseconds: 180),
                                                      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                                                      child: Icon(playing ? Icons.pause : Icons.play_arrow, key: ValueKey(playing), color: Colors.white, size: 32),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.skip_next, color: _gpmText, size: 30),
                                                onPressed: () => audioHandler.skipToNext(),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.thumb_down_off_alt, color: _gpmText, size: 24),
                                                onPressed: () {
                                                  audioHandler.skipToNext();
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), content: Text('Skipped track')));
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
              Padding(
                padding: EdgeInsets.all(14),
                child: Text('Queue', style: TextStyle(color: _gpmText, fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              Divider(height: 1, color: _gpmDivider),
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
                      subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmSub)),
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
          if (page == null) return Center(child: Text('Could not load album', style: TextStyle(color: _gpmSub)));
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
                          Text(page.title, style: TextStyle(color: _gpmText, fontSize: 19, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(page.artist, style: TextStyle(color: _gpmSub, fontSize: 14)),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: _gpmOrange, foregroundColor: Colors.white),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('PLAY'),
                            onPressed: () {
                              if (page.tracks.isEmpty) return;
                              audioHandler.playYouTubeList(page.tracks, 0, lockToScope: true);
                              _openGpmPlayer(context);
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
                    leading: Text('${i + 1}', style: TextStyle(color: _gpmSub, fontSize: 14)),
                    title: Text(page.tracks[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmText)),
                    subtitle: Text(page.tracks[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmSub, fontSize: 12.5)),
                    trailing: IconButton(icon: Icon(Icons.more_vert, color: _gpmSub), onPressed: () => showPlayMusicTrackMenu(context, page.tracks[i])),
                    onTap: () {
                      audioHandler.playYouTubeList(page.tracks, i, lockToScope: true);
                      _openGpmPlayer(context);
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
          if (page == null) return Center(child: Text('Could not load artist', style: TextStyle(color: _gpmSub)));
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
                          Text(page.name, style: TextStyle(color: _gpmText, fontSize: 22, fontWeight: FontWeight.w500)),
                          if (page.subscribersText != null) Text(page.subscribersText!, style: TextStyle(color: _gpmSub, fontSize: 13)),
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
                        _openGpmPlayer(context);
                      },
                    ),
                  ],
                ),
              ),
              Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Top songs', style: TextStyle(color: _gpmSub, fontWeight: FontWeight.w600))),
              for (var i = 0; i < min(10, page.songs.length); i++)
                Container(
                  color: _gpmWhite,
                  child: ListTile(
                    leading: SizedBox(width: 44, height: 44, child: _gpmArt(page.songs[i], size: 44)),
                    title: Text(page.songs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmText)),
                    subtitle: Text(page.plays[page.songs[i].id] ?? page.songs[i].artist, style: TextStyle(color: _gpmSub, fontSize: 12.5)),
                    trailing: IconButton(icon: Icon(Icons.more_vert, color: _gpmSub), onPressed: () => showPlayMusicTrackMenu(context, page.songs[i])),
                    onTap: () {
                      audioHandler.playYouTubeList(page.songs, i, lockToScope: true);
                      _openGpmPlayer(context);
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
                _openGpmPlayer(context);
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
            _openGpmPlayer(context);
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
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmText)),
                subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _gpmSub, fontSize: 12.5)),
                trailing: IconButton(icon: Icon(Icons.more_vert, color: _gpmSub), onPressed: () => showPlayMusicTrackMenu(context, t)),
                onTap: () {
                  audioHandler.playYouTubeList(tracks, i);
                  _openGpmPlayer(context);
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
  Navigator.of(context).push(_gpmActivityRoute(const RevivedSettingsScreen()));
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
          backgroundColor: _gpmBg,
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
                  title: Text(acc.signedIn ? (acc.name ?? 'YouTube Music account') : 'Tap to choose account', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                  subtitle: acc.signedIn ? Text('YouTube Music connected', style: TextStyle(color: _gpmSub, fontSize: 13)) : null,
                  onTap: () => showYtAccountSheet(context),
                ),
              ),
              Divider(height: 1, color: _gpmDivider),
              _gpmSection('APPEARANCE'),
              _gpmSwitch('Dark theme', 'Use classic dark Material theme', _gpmDark, (v) => appState.setB('gpm_dark_theme', v)),
              Divider(height: 1, color: _gpmDivider),
              _gpmSection('LIBRARY & STREAMING'),
              ListTile(
                title: Text('Import from Spotify', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                onTap: () => openSpotifyImport(context),
              ),
              Divider(height: 1, color: _gpmDivider),
              ListTile(
                title: Text('Offline downloads', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                subtitle: Text('${OfflineStore.count} songs • ${OfflineStore.formatBytes(OfflineStore.totalBytes)}', style: TextStyle(color: _gpmSub, fontSize: 13)),
                onTap: () => openDownloads(context),
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
              _gpmSection('PLAYBACK'),
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
              _gpmSection('ABOUT PLAY MUSIC'),
              ListTile(
                title: Text('Check for updates', style: TextStyle(color: _gpmText, fontSize: 15.5)),
                subtitle: Text(String.fromEnvironment('APP_BUILD_VER', defaultValue: 'v1.0.0'), style: TextStyle(color: _gpmSub, fontSize: 13)),
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
