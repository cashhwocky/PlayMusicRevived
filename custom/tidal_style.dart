import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai_features.dart';
import 'ai_music_chat.dart';
import 'main.dart';

const Color kTidalBg = Color(0xFF000000);
const Color kTidalSurface = Color(0xFF1A1A1D);
const Color kTidalDockBg = Color(0xFF1F1E22);
const Color kTidalPillActive = Color(0xFF333237);
const Color kTidalText1 = Color(0xFFFFFFFF);
const Color kTidalText2 = Color(0xFF9A9AA0);

/// Global tab switcher so tapping any tab on a sub-page (Search, Album,
/// Playlist, Artist) pops back to TidalAppShell AND switches to that exact tab.
final ValueNotifier<int?> tidalTabRequest = ValueNotifier<int?>(null);

void tidalNavigateToTab(BuildContext context, int tabIndex) {
  tidalTabRequest.value = tabIndex;
  Navigator.of(context).popUntil((route) => route.isFirst);
}

// ═══════════════════════════════════════════════════════════════════════════
// BITLMP APP ICON MARK (Disc with 3 sound bars for Tab 4: AI DJ)
// ═══════════════════════════════════════════════════════════════════════════

class TidalBitLmpMark extends StatelessWidget {
  final double size;
  final Color color;
  const TidalBitLmpMark({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BitLmpMarkPainter(color)),
    );
  }
}

class _BitLmpMarkPainter extends CustomPainter {
  final Color color;
  const _BitLmpMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = color);

    final cut = Paint()
      ..color = kTidalDockBg
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.13;
    const heights = [0.16, 0.28, 0.21];
    for (int i = -1; i <= 1; i++) {
      final x = c.dx + i * (size.width * 0.21);
      final h = size.height * heights[i + 1];
      canvas.drawLine(Offset(x, c.dy - h), Offset(x, c.dy + h), cut);
    }
  }

  @override
  bool shouldRepaint(covariant _BitLmpMarkPainter old) => old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════
// FLOATING UNIFIED TIDAL DOCK (Mini-player + 5 Tabs)
// Tab 0: Home | Tab 1: Updates | Tab 2: Explore | Tab 3: Library (|||) | Tab 4: AI (bitLMP mark)
// ═══════════════════════════════════════════════════════════════════════════

class TidalUnifiedDock extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onSelectTab;
  const TidalUnifiedDock({
    super.key,
    required this.selectedTab,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: audioHandler.currentIndex,
      builder: (context, _, __) {
        final track = audioHandler.currentTrack;
        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, snap) {
            final playing =
                (snap.data ?? audioHandler.playbackState.value).playing;
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: kTidalDockBg.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.07),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.65),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (track != null)
                        InkWell(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28)),
                          onTap: () => openPlayer(context),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: CustomAlbumArtwork(track: track),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: kTidalText2,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    playing
                                        ? audioHandler.pause()
                                        : audioHandler.play();
                                  },
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.black,
                                      size: 26,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 34, minHeight: 34),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    audioHandler.skipToNext();
                                  },
                                  icon: const Icon(
                                    Icons.skip_next_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            10, track != null ? 2 : 8, 10, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _navItem(0, Icons.music_note_rounded),
                            _navItem(1, Icons.notifications_none_rounded),
                            _navItem(2, Icons.search_rounded),
                            _navItem(3, Icons.library_music_rounded),
                            _navItem(4, Icons.auto_awesome_rounded),
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
      },
    );
  }

  Widget _navItem(int index, IconData icon) {
    final active = selectedTab == index;
    Widget child;
    if (index == 3) {
      // Tab 3: Library / Collection (||| bars)
      child = Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 2.2,
                height: 15,
                color: active ? Colors.white : kTidalText2),
            const SizedBox(width: 3.5),
            Container(
                width: 2.2,
                height: 15,
                color: active ? Colors.white : kTidalText2),
            const SizedBox(width: 3.5),
            Container(
                width: 2.2,
                height: 15,
                color: active ? Colors.white : kTidalText2),
          ],
        ),
      );
    } else if (index == 4) {
      // Tab 4: AI DJ (bitLMP disc-with-3-bars mark)
      child = Center(
        child: TidalBitLmpMark(
          size: 22,
          color: active ? Colors.white : kTidalText2,
        ),
      );
    } else {
      child = Icon(
        icon,
        size: 23,
        color: active ? Colors.white : kTidalText2,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onSelectTab(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58,
        height: 40,
        decoration: BoxDecoration(
          color: active ? kTidalPillActive : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIDAL FULL-SCREEN PLAYER
// ═══════════════════════════════════════════════════════════════════════════

class TidalPlayerView extends StatelessWidget {
  final TrackItem track;
  final bool playing;
  final bool loading;
  final bool shuffle;
  final AudioServiceRepeatMode repeat;
  final bool liked;

  const TidalPlayerView({
    super.key,
    required this.track,
    required this.playing,
    required this.loading,
    required this.shuffle,
    required this.repeat,
    required this.liked,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Color>(
      future: artSeedFor(track),
      initialData: artSeedNow(track),
      builder: (context, snap) {
        final seed = snap.data ?? const Color(0xFF534533);
        final topBg = Color.lerp(const Color(0xFF1A1714), seed, 0.42)!;
        final botBg = Color.lerp(const Color(0xFF0E0D0B), seed, 0.32)!;
        final nextTrack = audioHandler.peekNext;

        return Scaffold(
          backgroundColor: botBg,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topBg, botBg],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: SizedBox(
                            width: 76,
                            height: 44,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  child: ClipOval(
                                    child: SizedBox(
                                      width: 42,
                                      height: 42,
                                      child: CustomAlbumArtwork(track: track),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 32,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: topBg, width: 1.5),
                                    ),
                                    child: ClipOval(
                                      child: SizedBox(
                                        width: 42,
                                        height: 42,
                                        child: nextTrack != null
                                            ? CustomAlbumArtwork(
                                                track: nextTrack)
                                            : CustomAlbumArtwork(track: track),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => showPlaybackSheet(context),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.speaker_outlined,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),
                    AspectRatio(
                      aspectRatio: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.45),
                              blurRadius: 28,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SwipeArtCarousel(
                            track: track,
                            playing: playing,
                            radius: 8,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => goToAlbum(context, track),
                                child: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => goToArtist(context, track),
                                child: Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.68),
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            appState.toggleLike(track.id);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: liked
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              liked ? Icons.check_rounded : Icons.add_rounded,
                              color: liked ? Colors.black : Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    StreamBuilder<PlaybackState>(
                      stream: audioHandler.playbackState,
                      builder: (context, pSnap) {
                        final pos = pSnap.data?.position ?? Duration.zero;
                        final dur = audioHandler.player.duration ??
                            Duration(seconds: max(track.durationSeconds, 1));
                        final maxMs = max(dur.inMilliseconds, 1);
                        final val =
                            pos.inMilliseconds.clamp(0, maxMs).toDouble();
                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.0,
                                activeTrackColor: Colors.white,
                                inactiveTrackColor:
                                    Colors.white.withOpacity(0.24),
                                thumbColor: Colors.white,
                                thumbShape: const _TidalVerticalThumbShape(),
                                overlayShape: SliderComponentShape.noOverlay,
                              ),
                              child: Slider(
                                value: val,
                                min: 0,
                                max: maxMs.toDouble(),
                                onChanged: (v) {
                                  audioHandler.seek(
                                      Duration(milliseconds: v.round()));
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatDuration(pos),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  track.isYouTube
                                      ? '16-BIT 44.1kHz FLAC'
                                      : '24-BIT 48kHz FLAC',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                Text(
                                  formatDuration(dur),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => audioHandler.setShuffleMode(shuffle
                              ? AudioServiceShuffleMode.none
                              : AudioServiceShuffleMode.all),
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: shuffle
                                ? Colors.white
                                : Colors.white.withOpacity(0.55),
                            size: 24,
                          ),
                        ),
                        IconButton(
                          onPressed: audioHandler.skipToPrevious,
                          icon: const Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            playing
                                ? audioHandler.pause()
                                : audioHandler.play();
                          },
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Center(
                              child: loading
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: audioHandler.skipToNext,
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        IconButton(
                          onPressed: () => audioHandler.setRepeatMode(
                            repeat == AudioServiceRepeatMode.none
                                ? AudioServiceRepeatMode.all
                                : repeat == AudioServiceRepeatMode.all
                                    ? AudioServiceRepeatMode.one
                                    : AudioServiceRepeatMode.none,
                          ),
                          icon: Icon(
                            repeat == AudioServiceRepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: repeat != AudioServiceRepeatMode.none
                                ? Colors.white
                                : Colors.white.withOpacity(0.55),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ListenableBuilder(
                          listenable: AiDjState.i,
                          builder: (context, _) {
                            if (AiDjState.i.active) {
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  startOrStepAiDj();
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                      child: AiDjLogoIcon(size: 22)),
                                ),
                              );
                            }
                            return GestureDetector(
                              onTap: () => showQueueSheet(context),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notes_rounded,
                                  color: Colors.white,
                                  size: 21,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => showLyricsSheet(context, track),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Playing from',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  track.album.isNotEmpty
                                      ? track.album
                                      : (track.isYouTube
                                          ? 'YouTube Music'
                                          : 'Collection'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => shareTrack(track),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.share_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => showAddToPlaylistSheet(context, track),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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

class _TidalVerticalThumbShape extends SliderComponentShape {
  const _TidalVerticalThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(6, 16);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 5.5, height: 15),
      const Radius.circular(3),
    );
    context.canvas.drawRRect(rect, Paint()..color = Colors.white);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIDAL APP SHELL (5 Tabs: Home, Updates, Explore, Library, AI DJ)
// ═══════════════════════════════════════════════════════════════════════════

class TidalAppShell extends StatefulWidget {
  final List<TrackItem> tracks;
  final Widget Function(AppPalette pal) aiChatBuilder;
  const TidalAppShell({
    super.key,
    required this.tracks,
    required this.aiChatBuilder,
  });

  @override
  State<TidalAppShell> createState() => _TidalAppShellState();
}

class _TidalAppShellState extends State<TidalAppShell> {
  int _tab = 0; // 0=Home, 1=Updates, 2=Explore, 3=Library(|||), 4=AI(bitLMP mark)
  String _homeFilter = 'For you';
  bool _genresAsList = false;

  @override
  void initState() {
    super.initState();
    tidalTabRequest.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    tidalTabRequest.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final req = tidalTabRequest.value;
    if (req == null || !mounted) return;
    tidalTabRequest.value = null;
    setState(() => _tab = req);
  }

  void _playList(List<TrackItem> list, int i) {
    if (list.isEmpty) return;
    audioHandler.playYouTubeList(list, i.clamp(0, list.length - 1));
    openPlayer(context);
  }

  @override
  Widget build(BuildContext context) {
    final pal = appState.palette;
    Widget page;
    switch (_tab) {
      case 1:
        page = _buildUpdatesTab();
        break;
      case 2:
        page = _buildExploreTab();
        break;
      case 3:
        page = _buildCollectionTab();
        break;
      case 4:
        page = widget.aiChatBuilder(pal);
        break;
      default:
        page = _buildHomeTab();
    }

    return Scaffold(
      backgroundColor: kTidalBg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: page),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TidalUnifiedDock(
              selectedTab: _tab,
              onSelectTab: (i) => setState(() => _tab = i),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 0: HOME ──────────────────────────────────────────────────────────
  Widget _buildHomeTab() {
    final all = widget.tracks;
    final topPad = MediaQuery.of(context).padding.top;
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW - 32 - 14) / 2;

    final byArtist = <String, List<TrackItem>>{};
    for (final t in all) {
      if (t.artist.isNotEmpty && t.artist != 'Unknown Artist') {
        byArtist.putIfAbsent(t.artist, () => []).add(t);
      }
    }
    final sortedArtists = byArtist.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final featuredArtist =
        sortedArtists.isNotEmpty ? sortedArtists.first.key : 'Featured';
    final featuredTracks =
        sortedArtists.isNotEmpty ? sortedArtists.first.value : all;

    final gridItems = all.take(8).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad > 0 ? 8 : 16, 16, 165),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Home',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => showSettingsSheet(context),
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final pillLabel in ['For you', 'Staff Picks', 'Uploads'])
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _homeFilter = pillLabel);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: _homeFilter == pillLabel
                              ? Colors.white
                              : kTidalSurface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          pillLabel,
                          style: TextStyle(
                            color: _homeFilter == pillLabel
                                ? Colors.black
                                : Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              if (featuredTracks.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: CustomAlbumArtwork(track: featuredTracks.first),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Because you liked',
                      style: TextStyle(
                        color: kTidalText2,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      featuredArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _playList(featuredTracks, 0),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: kTidalText2,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (gridItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => showAddMusicSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Music'),
                ),
              ),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 18,
              children: [
                for (var i = 0; i < min(4, gridItems.length); i++)
                  GestureDetector(
                    onTap: () => _playList(gridItems, i),
                    child: SizedBox(
                      width: cardW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: cardW,
                              height: cardW,
                              child: CustomAlbumArtwork(track: gridItems[i]),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            gridItems[i].album.isNotEmpty &&
                                    gridItems[i].album != 'YouTube Music'
                                ? gridItems[i].album
                                : gridItems[i].title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            gridItems[i].artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kTidalText2,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 22),
          if (appState.b('ai_home_on', true))
            AiDjHomeCard(
              surface: kTidalSurface,
              text: Colors.white,
              subtext: kTidalText2,
              accent: Colors.white,
              onStartOrSkip: () => startOrStepAiDj(openInPlayer: context),
              onStop: () => stopAiDjSession(),
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Suggested new albums for you',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _playList(all, 0),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: kTidalText2,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (gridItems.length > 4)
            Wrap(
              spacing: 14,
              runSpacing: 18,
              children: [
                for (var i = 4; i < gridItems.length; i++)
                  GestureDetector(
                    onTap: () => _playList(gridItems, i),
                    child: SizedBox(
                      width: cardW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: cardW,
                              height: cardW,
                              child: CustomAlbumArtwork(track: gridItems[i]),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            gridItems[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            gridItems[i].artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kTidalText2,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // ── TAB 1: UPDATES ───────────────────────────────────────────────────────
  Widget _buildUpdatesTab() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 165),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Updates',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const Spacer(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 56,
                    color: Colors.white.withOpacity(0.75),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Follow your favourite artists and playlists to get\nthe latest updates here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kTidalText2,
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  // ── TAB 2: EXPLORE ───────────────────────────────────────────────────────
  Widget _buildExploreTab() {
    final all = widget.tracks;
    final spotlight = all.isNotEmpty ? all.first : null;
    const genres = [
      'Hip-Hop',
      'Pop',
      'R&B / Soul',
      'Country',
      'Electronic',
      'Rock',
      'Alternative',
      'Latin',
    ];

    void openTidalSearch([String? q]) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TidalSearchScreen(initialQuery: q),
      ));
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 165),
        children: [
          GestureDetector(
            onTap: () => openTidalSearch(),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: Colors.black87, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'From our tastemakers to your headphones.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (spotlight != null)
            GestureDetector(
              onTap: () => _playList(all, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 290,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          spotlight.artColors.first.withOpacity(0.85),
                          const Color(0xFF231D18),
                        ],
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 185,
                        height: 185,
                        child: CustomAlbumArtwork(track: spotlight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'FEATURED SPOTLIGHT',
                    style: TextStyle(
                      color: Color(0xFF22D3EE),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    spotlight.artist,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spotlight.title,
                    style: const TextStyle(color: kTidalText2, fontSize: 14),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Genres',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _genresAsList = !_genresAsList),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kTidalSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _genresAsList ? 'VIEW AS PILLS' : 'VIEW AS LIST',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_genresAsList)
            Column(
              children: [
                for (final g in genres)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(g,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: kTidalText2),
                    onTap: () => openTidalSearch(g),
                  ),
              ],
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final g in genres)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => openTidalSearch(g),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 13),
                          decoration: BoxDecoration(
                            color: kTidalSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            g,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── TAB 3: COLLECTION / LIBRARY (|||) ────────────────────────────────────
  Widget _buildCollectionTab() {
    final all = widget.tracks;
    final recent = <TrackItem>[];
    for (final id in appState.recent) {
      final t = audioHandler.trackById(id);
      if (t != null && !recent.contains(t)) recent.add(t);
    }
    if (recent.isEmpty) recent.addAll(all.take(6));

    Widget rowItem(IconData icon, String label, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Icon(icon, color: Colors.white70, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 16, 165),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Collection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const StatsButton(),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => showSettingsSheet(context),
                icon: const Icon(Icons.settings_outlined,
                    color: Colors.white, size: 24),
              ),
              GestureDetector(
                onTap: () => showYtAccountSheet(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38, width: 1.2),
                  ),
                  child: const Icon(Icons.person_outline_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          rowItem(Icons.sensors_rounded, 'Mixes & Radio', () {
            startOrStepAiDj(openInPlayer: context);
          }),
          rowItem(Icons.queue_music_rounded, 'Playlists', () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const TidalPlaylistsScreen(),
            ));
          }),
          rowItem(Icons.album_outlined, 'Albums', () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const TidalSearchScreen(),
            ));
          }),
          rowItem(Icons.pause_rounded, 'Purchases', () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
            );
          }),
          rowItem(Icons.music_note_outlined, 'Tracks', () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
            );
          }),
          rowItem(Icons.play_arrow_outlined, 'Videos', () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const TidalSearchScreen(),
            ));
          }),
          rowItem(Icons.mic_none_rounded, 'Artists', () {
            if (all.isNotEmpty) goToArtist(context, all.first);
          }),
          rowItem(Icons.arrow_circle_down_outlined, 'Downloads', () {
            openDownloads(context);
          }),
          const SizedBox(height: 20),
          const Text(
            'Recent activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 155,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final t = recent[i];
                return GestureDetector(
                  onTap: () => _playList(recent, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: CustomAlbumArtwork(track: t),
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

// ═══════════════════════════════════════════════════════════════════════════
// EXCLUSIVE TIDAL SEARCH SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class TidalSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const TidalSearchScreen({super.key, this.initialQuery});

  @override
  State<TidalSearchScreen> createState() => _TidalSearchScreenState();
}

class _TidalSearchScreenState extends State<TidalSearchScreen> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialQuery ?? '');
  Timer? _debounce;
  String _filter = 'Top results';
  bool _loading = false;
  List<TrackItem> _tracks = [];
  List<YtAlbum> _albums = [];
  List<YtArtist> _artists = [];
  List<YtPlaylistRef> _playlists = [];

  static const _filters = [
    'Top results',
    'Tracks',
    'Playlists',
    'Albums',
    'Artists',
  ];

  @override
  void initState() {
    super.initState();
    if (_ctrl.text.trim().isNotEmpty) {
      _runSearch(_ctrl.text.trim());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    setState(() {});
    _debounce?.cancel();
    final q = val.trim();
    if (q.isEmpty) {
      _runSearch('');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), () {
      _runSearch(q);
    });
  }

  Future<void> _runSearch(String q) async {
    if (q.isEmpty) {
      setState(() {
        _tracks = [];
        _albums = [];
        _artists = [];
        _playlists = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final local = audioHandler.tracks
          .where((t) =>
              t.title.toLowerCase().contains(q.toLowerCase()) ||
              t.artist.toLowerCase().contains(q.toLowerCase()))
          .toList();
      final results = await Future.wait([
        YouTubeMusic.search(q).catchError((_) => const <TrackItem>[]),
        YouTubeMusic.searchAlbums(q).catchError((_) => const <YtAlbum>[]),
        YouTubeMusic.searchArtists(q).catchError((_) => const <YtArtist>[]),
        YouTubeMusic.searchPlaylists(q)
            .catchError((_) => const <YtPlaylistRef>[]),
      ]);
      if (!mounted) return;
      final ytTracks = results[0] as List<TrackItem>;
      final merged = <TrackItem>[...local];
      final seen = <String>{for (final t in local) t.id};
      for (final t in ytTracks) {
        if (seen.add(t.id)) merged.add(t);
      }
      setState(() {
        _tracks = merged;
        _albums = results[1] as List<YtAlbum>;
        _artists = results[2] as List<YtArtist>;
        _playlists = results[3] as List<YtPlaylistRef>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTidalBg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 14, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 24),
                      ),
                      Expanded(
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded,
                                  color: Colors.black87, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _ctrl,
                                  autofocus: widget.initialQuery == null,
                                  textInputAction: TextInputAction.search,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Search',
                                    hintStyle: TextStyle(color: Colors.black45),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onSubmitted: (v) => _runSearch(v.trim()),
                                  onChanged: _onChanged,
                                ),
                              ),
                              if (_ctrl.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _ctrl.clear();
                                    _runSearch('');
                                  },
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.black87, size: 21),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = _filters[i];
                      final on = _filter == f;
                      return GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: on ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: on ? Colors.black : Colors.white70,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : _buildResultsList(),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TidalUnifiedDock(
              selectedTab: 2,
              onSelectTab: (i) => tidalNavigateToTab(context, i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    final items = <Widget>[];

    Widget trackTile(TrackItem t, List<TrackItem> list, int idx) => InkWell(
          onTap: () {
            audioHandler.playYouTubeList(list, idx);
            openPlayer(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: CustomAlbumArtwork(track: t),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Track by ${t.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: kTidalText2, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => showYtAddToPlaylist(context, t),
                  icon: const Icon(Icons.more_vert_rounded,
                      color: kTidalText2, size: 20),
                ),
              ],
            ),
          ),
        );

    Widget albumTile(YtAlbum a) => InkWell(
          onTap: () => openYtAlbum(context, a),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: YtNetworkImage(url: a.thumbnail, size: 52),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Album by ${a.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: kTidalText2, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_vert_rounded,
                    color: kTidalText2, size: 20),
              ],
            ),
          ),
        );

    Widget artistTile(YtArtist a) => InkWell(
          onTap: () =>
              openYtArtist(context, a.url, a.name, thumbnail: a.thumbnail),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                YtNetworkImage(
                  url: a.thumbnail,
                  size: 52,
                  circle: true,
                  fallbackIcon: Icons.person_rounded,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text('Artist',
                          style: TextStyle(color: kTidalText2, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    Widget playlistTile(YtPlaylistRef p) => InkWell(
          onTap: () => openYtAccountPlaylist(context, p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: YtNetworkImage(url: p.thumbnail, size: 52),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        p.subtitle.isEmpty ? 'Playlist' : p.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: kTidalText2, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    if (_filter == 'Tracks') {
      for (var i = 0; i < _tracks.length; i++) {
        items.add(trackTile(_tracks[i], _tracks, i));
      }
    } else if (_filter == 'Albums') {
      for (final a in _albums) items.add(albumTile(a));
    } else if (_filter == 'Artists') {
      for (final a in _artists) items.add(artistTile(a));
    } else if (_filter == 'Playlists') {
      for (final p in _playlists) items.add(playlistTile(p));
    } else {
      for (var i = 0; i < min(3, _tracks.length); i++) {
        items.add(trackTile(_tracks[i], _tracks, i));
      }
      if (_albums.isNotEmpty) items.add(albumTile(_albums.first));
      if (_artists.isNotEmpty) items.add(artistTile(_artists.first));
      for (var i = 3; i < _tracks.length; i++) {
        items.add(trackTile(_tracks[i], _tracks, i));
      }
    }

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Search for tracks, albums, artists, or playlists',
          style: TextStyle(color: kTidalText2, fontSize: 14.5),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 165),
      children: items,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIDAL PLAYLISTS SCREEN (YouTube Music + Local Playlists)
// ═══════════════════════════════════════════════════════════════════════════

class TidalPlaylistsScreen extends StatefulWidget {
  const TidalPlaylistsScreen({super.key});

  @override
  State<TidalPlaylistsScreen> createState() => _TidalPlaylistsScreenState();
}

class _TidalPlaylistsScreenState extends State<TidalPlaylistsScreen> {
  late Future<List<YtPlaylistRef>> _ytFuture;

  @override
  void initState() {
    super.initState();
    _ytFuture = YouTubeMusic.libraryPlaylists().catchError(
        (_) => YouTubeMusic.cachedLibrary() ?? const <YtPlaylistRef>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kTidalBg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 165),
              children: [
                Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const Expanded(
                      child: Text(
                        'Playlists',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => showCreateOrEditPlaylistDialog(context),
                      icon: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _plRow(
                  cover: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        color: Color(0xFF22D3EE), size: 26),
                  ),
                  title: 'Liked on YouTube Music',
                  subtitle: 'Auto playlist',
                  onTap: () => openYtLikedMusic(context),
                ),
                for (final pl in appState.playlists)
                  _plRow(
                    cover: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: PlaylistCoverThumbnail(playlist: pl, size: 56),
                    ),
                    title: pl.name,
                    subtitle: '${pl.trackIds.length} tracks · Local',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(playlistId: pl.id),
                    )),
                  ),
                FutureBuilder<List<YtPlaylistRef>>(
                  future: _ytFuture,
                  initialData: YouTubeMusic.cachedLibrary(),
                  builder: (context, snap) {
                    final list = snap.data ?? const <YtPlaylistRef>[];
                    if (list.isEmpty &&
                        snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child:
                                CircularProgressIndicator(color: Colors.white)),
                      );
                    }
                    return Column(
                      children: [
                        for (final p in list)
                          _plRow(
                            cover: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: YtNetworkImage(url: p.thumbnail, size: 56),
                            ),
                            title: p.title,
                            subtitle: p.subtitle.isEmpty
                                ? 'YouTube Music'
                                : p.subtitle,
                            onTap: () => openYtAccountPlaylist(context, p),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TidalUnifiedDock(
              selectedTab: 3,
              onSelectTab: (i) => tidalNavigateToTab(context, i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _plRow({
    required Widget cover,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            cover,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kTidalText2, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kTidalText2),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIDAL ALBUM & YTM PLAYLIST VIEW
// ═══════════════════════════════════════════════════════════════════════════

Widget buildTidalAlbumView(
  BuildContext context,
  YtAlbum album,
  AsyncSnapshot<YtAlbumPage> snap,
  YtAlbumPage? cached, {
  bool isPlaylist = false,
}) {
  final page = snap.data ?? cached;
  final cover = page?.thumbnail ?? album.thumbnail;
  final title = page?.title ?? album.title;
  final artist =
      (page?.artist.isNotEmpty ?? false) ? page!.artist : album.artist;
  final tracks = page?.tracks ?? const <TrackItem>[];
  final year = page?.year ?? '';
  final secs = tracks.fold<int>(0, (a, t) => a + t.durationSeconds);
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  final durText = h > 0 ? '$h HR $m MIN' : '$m MIN';

  void playAt(int i, {bool shuffle = false}) {
    if (tracks.isEmpty) return;
    audioHandler.setShuffleMode(
        shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none);
    audioHandler.playYouTubeList(tracks, i, lockToScope: true);
    openPlayer(context);
  }

  Widget actionBtn(IconData icon, String label, VoidCallback onTap,
          {Color color = Colors.white}) =>
      GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  return Scaffold(
    backgroundColor: kTidalBg,
    body: Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 165),
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF443E37),
                    Color(0xFF1C1917),
                    kTidalBg,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 24),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              if (tracks.isNotEmpty) {
                                audioHandler.addToQueue(tracks);
                                appNotice.value = 'Added $title to queue';
                              }
                            },
                            icon: const Icon(Icons.more_vert_rounded,
                                color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.55),
                              blurRadius: 26,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: YtNetworkImage(
                              url: cover, size: isPlaylist ? 140 : 172),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isPlaylist ? 'by $artist >' : 'Album by $artist >',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: kTidalText2,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isPlaylist)
                        Text(
                          '${tracks.length} TRACKS ($durText)',
                          style: const TextStyle(
                            color: kTidalText2,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (year.isNotEmpty) ...[
                              Text(
                                year,
                                style: const TextStyle(
                                  color: kTidalText2,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E3A3B),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'HIGH',
                                style: TextStyle(
                                  color: Color(0xFF2DD4BF),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => playAt(0),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                color: Colors.black, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Play',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => playAt(
                        tracks.isEmpty ? 0 : Random().nextInt(tracks.length),
                        shuffle: true,
                      ),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: kTidalSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shuffle_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Shuffle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
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
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  actionBtn(Icons.favorite_border_rounded, 'Add', () {
                    if (tracks.isNotEmpty) {
                      appState.toggleLike(tracks.first.id);
                      appNotice.value = 'Saved $title';
                    }
                  }),
                  actionBtn(Icons.info_outline_rounded, 'Credits', () {
                    showAiSongInfo(
                      context,
                      title: title,
                      artist: artist,
                      onPlay: (_) {},
                    );
                  }),
                  actionBtn(Icons.arrow_circle_down_outlined, 'Download', () {
                    openDownloads(context);
                  }),
                  actionBtn(Icons.share_outlined, 'Share', () {
                    if (tracks.isNotEmpty) shareTrack(tracks.first);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (tracks.isEmpty && snap.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              )
            else
              for (var i = 0; i < tracks.length; i++)
                InkWell(
                  onTap: () => playAt(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    child: Row(
                      children: [
                        if (isPlaylist) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: CustomAlbumArtwork(track: tracks[i]),
                            ),
                          ),
                          const SizedBox(width: 14),
                        ] else
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: kTidalText2,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tracks[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: audioHandler.currentTrack?.id ==
                                          tracks[i].id
                                      ? const Color(0xFF2DD4BF)
                                      : Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tracks[i].artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: kTidalText2, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              showYtAddToPlaylist(context, tracks[i]),
                          icon: const Icon(Icons.more_vert_rounded,
                              color: kTidalText2, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
            if (!isPlaylist && year.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Text(
                  'Release date: $year\n$artist',
                  style: const TextStyle(
                    color: kTidalText2,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: TidalUnifiedDock(
            selectedTab: isPlaylist ? 3 : 0,
            onSelectTab: (i) => tidalNavigateToTab(context, i),
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// TIDAL LOCAL PLAYLIST VIEW
// ═══════════════════════════════════════════════════════════════════════════

Widget buildTidalPlaylistView(
  BuildContext context,
  Playlist pl,
  List<TrackItem> tracks,
  void Function(int i) playFrom,
) {
  final secs = tracks.fold<int>(0, (a, t) => a + t.durationSeconds);
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  final durText = h > 0 ? '$h HR $m MIN' : '$m MIN';

  Widget actionBtn(IconData icon, String label, VoidCallback onTap,
          {Color color = Colors.white}) =>
      GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  return Scaffold(
    backgroundColor: kTidalBg,
    body: Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 165),
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF5A5550), Color(0xFF262321), kTidalBg],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 24),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TidalSearchScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.search_rounded,
                                color: Colors.white, size: 23),
                          ),
                          IconButton(
                            onPressed: () => showCreateOrEditPlaylistDialog(
                                context,
                                existing: pl),
                            icon: const Icon(Icons.more_vert_rounded,
                                color: Colors.white, size: 23),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: PlaylistCoverThumbnail(playlist: pl, size: 130),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        pl.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'by you >',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${tracks.length} TRACKS ($durText)',
                        style: const TextStyle(
                          color: kTidalText2,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (tracks.isNotEmpty) {
                          audioHandler
                              .setShuffleMode(AudioServiceShuffleMode.none);
                          playFrom(0);
                        }
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                color: Colors.black, size: 22),
                            SizedBox(width: 6),
                            Text(
                              'Play',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (tracks.isNotEmpty) {
                          audioHandler
                              .setShuffleMode(AudioServiceShuffleMode.all);
                          playFrom(Random().nextInt(tracks.length));
                        }
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: kTidalSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shuffle_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Shuffle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
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
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  actionBtn(Icons.edit_outlined, 'Edit playlist', () {
                    showCreateOrEditPlaylistDialog(context, existing: pl);
                  }),
                  actionBtn(Icons.arrow_circle_down_outlined, 'Download', () {
                    openDownloads(context);
                  }),
                  actionBtn(Icons.lock_open_rounded, 'Public', () {},
                      color: const Color(0xFF2DD4BF)),
                  actionBtn(Icons.share_outlined, 'Share', () {
                    if (tracks.isNotEmpty) shareTrack(tracks.first);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < tracks.length; i++)
              InkWell(
                onTap: () => playFrom(i),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: CustomAlbumArtwork(track: tracks[i]),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tracks[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: audioHandler.currentTrack?.id ==
                                        tracks[i].id
                                    ? const Color(0xFF2DD4BF)
                                    : Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tracks[i].artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: kTidalText2, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            showAddToPlaylistSheet(context, tracks[i]),
                        icon: const Icon(Icons.more_vert_rounded,
                            color: kTidalText2, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: TidalUnifiedDock(
            selectedTab: 3,
            onSelectTab: (i) => tidalNavigateToTab(context, i),
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// TIDAL ARTIST PAGE
// ═══════════════════════════════════════════════════════════════════════════

Widget buildTidalArtistView(
  BuildContext context,
  String fallbackName,
  YtArtistPage? page,
  AsyncSnapshot<YtArtistPage> snap,
  void Function(List<TrackItem> songs, int i, {bool shuffle}) onPlay,
) {
  final name = page?.name ?? fallbackName;
  final songs = page?.songs ?? const <TrackItem>[];
  final fansText = page?.subscribersText != null
      ? '${page!.subscribersText} fans'
      : (page != null && page.subscribers >= 0)
          ? '${formatCompactCount(page.subscribers)} fans'
          : '${songs.length} fans';

  return Scaffold(
    backgroundColor: kTidalBg,
    body: Stack(
      children: [
        SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 165),
            children: [
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerRight,
                    onPressed: () {
                      if (songs.isNotEmpty) {
                        audioHandler.addToQueue(songs);
                        appNotice.value = 'Added $name to queue';
                      }
                    },
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                fansText,
                style: const TextStyle(
                  color: kTidalText2,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (songs.isNotEmpty) onPlay(songs, 0);
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.black, size: 30),
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () {
                      if (songs.isNotEmpty) {
                        audioHandler.addToQueue(songs, next: true);
                        appNotice.value = 'Following $name';
                      }
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: kTidalSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () {
                      if (songs.isNotEmpty) shareTrack(songs.first);
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: kTidalSurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.ios_share_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        children: [
                          const Text(
                            'All',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(width: 22, height: 2.5, color: Colors.white),
                        ],
                      ),
                      const SizedBox(width: 24),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10.5),
                        child: Text(
                          'Music',
                          style: TextStyle(
                            color: kTidalText2,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.10),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Top Tracks',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => openArtistAll(context, name, albums: false),
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        color: kTidalText2,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (page == null && snap.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                )
              else
                for (var i = 0; i < min(6, songs.length); i++)
                  InkWell(
                    onTap: () => onPlay(songs, i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: CustomAlbumArtwork(track: songs[i]),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  songs[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  songs[i].artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kTidalText2,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                showYtAddToPlaylist(context, songs[i]),
                            icon: const Icon(Icons.more_vert_rounded,
                                color: kTidalText2, size: 21),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: TidalUnifiedDock(
            selectedTab: 0,
            onSelectTab: (i) => tidalNavigateToTab(context, i),
          ),
        ),
      ],
    ),
  );
}
