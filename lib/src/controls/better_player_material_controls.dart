import 'dart:async';
import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player/src/controls/better_player_clickable_widget.dart';
import 'package:better_player/src/controls/better_player_controls_state.dart';
import 'package:better_player/src/controls/better_player_material_progress_bar.dart';
import 'package:better_player/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player/src/controls/better_player_progress_colors.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:flutter/cupertino.dart';

// Flutter imports:
import 'package:flutter/material.dart';

class BetterPlayerMaterialControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerMaterialControls({
    Key? key,
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerMaterialControlsState();
  }
}

class _BetterPlayerMaterialControlsState
    extends BetterPlayerControlsState<BetterPlayerMaterialControls> {
  VideoPlayerValue? _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  Timer? _showAfterExpandCollapseTimer;
  bool _displayTapped = false;
  bool _wasLoading = false;
  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;

  double? _latestPlaySpeed;

  int? _latestSeconds;
  int? _seekedSeconds;
  bool wasSeeking = false;
  double? horizontalDragStartPosition;

  bool get isFullScreen => _betterPlayerController?.isFullScreen ?? false;

  double get controllIconPadding => isFullScreen ? 16 : 12;

  double get controllIconSize => isFullScreen ? 30 : 24;

  double get controlBarHeight => isFullScreen ? 48 : 28;

  BetterPlayerControlsConfiguration get _controlsConfiguration =>
      widget.controlsConfiguration;

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      _controlsConfiguration;

  @override
  Widget build(BuildContext context) {
    return buildLTRDirectionality(_buildMainWidget());
  }

  ///Builds main widget of the controls.
  Widget _buildMainWidget() {
    _wasLoading = isLoading(_latestValue);
    if (_latestValue?.hasError == true) {
      return Container(
        color: Colors.black,
        child: _buildErrorWidget(),
      );
    }
    return GestureDetector(
      onTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onTap?.call();
        }
        controlsNotVisible
            ? cancelAndRestartTimer()
            : changePlayerControlsNotVisible(true);
      },
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
      onVerticalDragEnd: (_) {},
      onHorizontalDragStart: (detail) {
        if (_controller != null && latestValue!.initialized) {
          wasSeeking = true;
          _seekedSeconds = 0;
          _latestSeconds = _controller!.value.position.inSeconds;
          horizontalDragStartPosition = detail.globalPosition.dx;
          cancelAndRestartTimer();
        }
      },
      onHorizontalDragUpdate: (details) {
        if (wasSeeking) {
          cancelAndRestartTimer();
          final double delta =
              details.globalPosition.dx - horizontalDragStartPosition!;
          final seekedSecondsAbs =
              (delta.abs() / MediaQuery.of(context).size.width) * 90; // 滑动多少秒
          final seekedSeconds =
              delta > 0 ? seekedSecondsAbs : -seekedSecondsAbs; //// 滑动多少秒
          final countSeconds = latestValue!.duration!.inSeconds; // 总秒数
          final end = _latestSeconds! + seekedSeconds; // 结束秒数

          if (end >= countSeconds) {
            _seekedSeconds = countSeconds - _latestSeconds!;
            return;
          } else if (end <= 0) {
            _seekedSeconds = -_latestSeconds!;
            return;
          }
          _seekedSeconds = seekedSeconds.toInt();
        }
      },
      onHorizontalDragEnd: (_) async {
        if (wasSeeking) {
          await betterPlayerController!.seekTo(
              Duration(seconds: _latestSeconds! + _seekedSeconds!.toInt()));
          wasSeeking = false;
        }
      },
      onLongPressStart: (_) {
        if (_betterPlayerController?.isPlaying() == false) {
          return;
        }
        _latestPlaySpeed = _controller?.value.speed ?? 1.0;
        if (_.globalPosition.dx >= (MediaQuery.of(context).size.width / 2)) {
          _controller?.setSpeed(
              _latestPlaySpeed! * 2 > 2.0 ? 4.0 : _latestPlaySpeed! * 2);
        }
      },
      onLongPressEnd: (_) {
        if (_latestPlaySpeed != null) {
          _betterPlayerController?.setSpeed(_latestPlaySpeed!);
          _latestPlaySpeed = null;
          setState(() {});
        }
      },
      onDoubleTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onDoubleTap?.call();
        }
        cancelAndRestartTimer();
        _betterPlayerController?.isPlaying() ?? false
            ? _betterPlayerController?.pause()
            : _betterPlayerController?.play();
      },
      onLongPress: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onLongPress?.call();
        }
      },
      child: AbsorbPointer(
        absorbing: controlsNotVisible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_wasLoading)
              Center(child: _buildLoadingWidget())
            else
              _buildHitArea(),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),
            if (_latestPlaySpeed != null)
              Container(
                alignment: Alignment.topCenter,
                margin: EdgeInsets.only(
                  top: betterPlayerControlsConfiguration.controlBarHeight + 10,
                ),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(48),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.bolt_fill,
                        color: betterPlayerControlsConfiguration.iconsColor,
                        size: 14,
                      ),
                      Text(
                        ' ${_controller?.value.speed ?? 1.0}x',
                        style: TextStyle(
                          fontSize: 12,
                          color: _controlsConfiguration.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
            _buildNextVideoWidget(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    _latestValue = _controller!.value;

    if (_oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildErrorWidget() {
    final errorBuilder =
        _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(
          context,
          _betterPlayerController!
              .videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              color: _controlsConfiguration.iconsColor,
              size: 42,
            ),
            Text(
              _betterPlayerController!.translations.generalDefaultError,
              style: textStyle,
            ),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _betterPlayerController!.retryDataSource();
                },
                child: Text(
                  _betterPlayerController!.translations.generalRetry,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      );
    }
  }

  Widget _buildTopBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }

    return Container(
      child: (_controlsConfiguration.enableOverflowMenu)
          ? AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              onEnd: _onPlayerHide,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                width: double.infinity,
                height: controlBarHeight,
                padding: EdgeInsets.symmetric(horizontal: controllIconPadding),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop() &&
                        _controlsConfiguration.enableBackButton)
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.back,
                          color: _controlsConfiguration.iconsColor,
                          size: controllIconSize,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    Expanded(
                      child: _betterPlayerController
                                  ?.betterPlayerDataSource?.title !=
                              null
                          ? Text(
                              _betterPlayerController!
                                  .betterPlayerDataSource!.title!,
                              style: TextStyle(
                                color: _controlsConfiguration.textColor,
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                            )
                          : const SizedBox(),
                    ),
                    if (_controlsConfiguration.enablePip)
                      _buildPipButtonWrapperWidget(
                          controlsNotVisible, _onPlayerHide)
                    else
                      const SizedBox(),
                    _buildMoreButton(),
                  ],
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildPipButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        betterPlayerController!.enablePictureInPicture(
            betterPlayerController!.betterPlayerGlobalKey!);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: controllIconPadding / 2),
        child: Icon(
          betterPlayerControlsConfiguration.pipMenuIcon,
          color: betterPlayerControlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPipButtonWrapperWidget(
      bool hideStuff, void Function() onPlayerHide) {
    return FutureBuilder<bool>(
      future: betterPlayerController!.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final bool isPipSupported = snapshot.data ?? false;
        if (isPipSupported &&
            _betterPlayerController!.betterPlayerGlobalKey != null) {
          return AnimatedOpacity(
            opacity: hideStuff ? 0.0 : 1.0,
            duration: betterPlayerControlsConfiguration.controlsHideTime,
            onEnd: onPlayerHide,
            child: _buildPipButton(),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMoreButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        onShowMoreClicked();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: controllIconPadding / 2),
        child: Icon(
          _controlsConfiguration.overflowMenuIcon,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return AnimatedOpacity(
      opacity: (controlsNotVisible && !wasSeeking) ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        height: controlBarHeight,
        padding: EdgeInsets.symmetric(horizontal: controllIconPadding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 75,
              child: Row(
                children: [
                  if (_controlsConfiguration.enablePlayPause)
                    _buildPlayPause(_controller!)
                  else
                    const SizedBox(),
                  if (_betterPlayerController!.isLiveStream())
                    _buildLiveWidget()
                  else
                    _controlsConfiguration.enableProgressText
                        ? _buildPosition()
                        : const SizedBox(),
                  if (_betterPlayerController!.isLiveStream())
                    const SizedBox()
                  else
                    _controlsConfiguration.enableProgressBar
                        ? _buildProgressBar()
                        : const SizedBox(),
                  if (_controlsConfiguration.enableMute)
                    _buildMuteButton(_controller)
                  else
                    const SizedBox(),
                  if (_controlsConfiguration.enableFullscreen)
                    _buildExpandButton()
                  else
                    const SizedBox(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveWidget() {
    return Text(
      _betterPlayerController!.translations.controlsLive,
      style: TextStyle(
        color: _controlsConfiguration.liveTextColor,
        fontWeight: FontWeight.bold,
        fontSize: isFullScreen ? 12.0 : 10.0,
      ),
    );
  }

  Widget _buildExpandButton() {
    return BetterPlayerMaterialClickableWidget(
      onTap: _onExpandCollapse,
      child: Container(
        child: Center(
          child: Icon(
            _betterPlayerController!.isFullScreen
                ? _controlsConfiguration.fullscreenDisableIcon
                : _controlsConfiguration.fullscreenEnableIcon,
            color: _controlsConfiguration.iconsColor,
            size: controllIconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return Container(
      child: Center(
        child: AnimatedOpacity(
          opacity: controlsNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: _buildMiddleRow(),
        ),
      ),
    );
  }

  Widget _buildMiddleRow() {
    return Container(
      color: _controlsConfiguration.controlBarColor,
      width: double.infinity,
      height: double.infinity,
      child: _betterPlayerController?.isLiveStream() == true
          ? const SizedBox()
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReplayButton(_controller!),
              ],
            ),
    );
  }

  Widget _buildHitAreaClickableButton(
      {Widget? icon, required void Function() onClicked}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 80.0, maxWidth: 80.0),
      child: BetterPlayerMaterialClickableWidget(
        onTap: onClicked,
        child: Align(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [icon!],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplayButton(VideoPlayerController controller) {
    final bool isFinished = isVideoFinished(_latestValue);
    return _buildHitAreaClickableButton(
      icon: isFinished
          ? Icon(
              Icons.replay,
              size: 42,
              color: _controlsConfiguration.iconsColor,
            )
          : Icon(
              controller.value.isPlaying
                  ? _controlsConfiguration.pauseIcon
                  : _controlsConfiguration.playIcon,
              size: 42,
              color: _controlsConfiguration.iconsColor,
            ),
      onClicked: () {
        if (isFinished) {
          if (_latestValue != null && _latestValue!.isPlaying) {
            if (_displayTapped) {
              changePlayerControlsNotVisible(true);
            } else {
              cancelAndRestartTimer();
            }
          } else {
            _onPlayPause();
            changePlayerControlsNotVisible(true);
          }
        } else {
          _onPlayPause();
        }
      },
    );
  }

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int?>(
      stream: _betterPlayerController!.nextVideoTimeStream,
      builder: (context, snapshot) {
        final time = snapshot.data;
        if (time != null && time > 0) {
          return BetterPlayerMaterialClickableWidget(
            onTap: () {
              _betterPlayerController!.playNextVideo();
            },
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: EdgeInsets.only(
                    bottom: _controlsConfiguration.controlBarHeight + 20,
                    right: 24),
                decoration: BoxDecoration(
                  color: _controlsConfiguration.controlBarColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "${_betterPlayerController!.translations.controlsNextVideoIn} $time...",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMuteButton(
    VideoPlayerController? controller,
  ) {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        cancelAndRestartTimer();
        if (_latestValue!.volume == 0) {
          _betterPlayerController!.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller!.value.volume;
          _betterPlayerController!.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRect(
          child: Container(
            height: _controlsConfiguration.controlBarHeight,
            padding: EdgeInsets.only(right: controllIconPadding),
            child: Icon(
              (_latestValue != null && _latestValue!.volume > 0)
                  ? _controlsConfiguration.muteIcon
                  : _controlsConfiguration.unMuteIcon,
              color: _controlsConfiguration.iconsColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPause(VideoPlayerController controller) {
    return BetterPlayerMaterialClickableWidget(
      key: const Key("better_player_material_controls_play_pause_button"),
      onTap: _onPlayPause,
      child: Container(
        height: double.infinity,
        padding: EdgeInsets.only(right: controllIconPadding),
        child: Icon(
          controller.value.isPlaying
              ? _controlsConfiguration.pauseIcon
              : _controlsConfiguration.playIcon,
          color: _controlsConfiguration.iconsColor,
          size: controllIconSize,
        ),
      ),
    );
  }

  Widget _buildPosition() {
    final position =
        _latestValue != null ? _latestValue!.position : Duration.zero;
    final duration = _latestValue != null && _latestValue!.duration != null
        ? _latestValue!.duration!
        : Duration.zero;

    return Padding(
      padding: EdgeInsets.only(right: controllIconPadding),
      child: RichText(
        text: TextSpan(
            text: BetterPlayerUtils.formatDuration(
              wasSeeking
                  ? Duration(seconds: _latestSeconds! + _seekedSeconds!)
                  : position,
            ),
            style: TextStyle(
              fontSize: isFullScreen ? 12.0 : 10.0,
              fontWeight: FontWeight.bold,
              color: _controlsConfiguration.textColor,
              decoration: TextDecoration.none,
            ),
            children: <TextSpan>[
              TextSpan(
                text: '/${BetterPlayerUtils.formatDuration(duration)}',
                style: TextStyle(
                  fontSize: isFullScreen ? 12.0 : 10.0,
                  fontWeight: FontWeight.bold,
                  color: _controlsConfiguration.textColor,
                  decoration: TextDecoration.none,
                ),
              )
            ]),
      ),
    );
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    changePlayerControlsNotVisible(false);
    _displayTapped = true;
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);

    _updateState();

    if ((_controller!.value.isPlaying) ||
        _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }

    _controlsVisibilityStreamSubscription =
        _betterPlayerController!.controlsVisibilityStream.listen((state) {
      changePlayerControlsNotVisible(!state);
      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

  void _onExpandCollapse() {
    changePlayerControlsNotVisible(true);
    _betterPlayerController!.toggleFullScreen();
    _showAfterExpandCollapseTimer =
        Timer(_controlsConfiguration.controlsHideTime, () {
      setState(() {
        cancelAndRestartTimer();
      });
    });
  }

  void _onPlayPause() {
    bool isFinished = false;

    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _betterPlayerController!.pause();
    } else {
      cancelAndRestartTimer();

      if (!_controller!.value.initialized) {
      } else {
        if (isFinished) {
          _betterPlayerController!.seekTo(const Duration());
        }
        _betterPlayerController!.play();
        _betterPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(milliseconds: 3000), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      _latestValue = _controller!.value;
      if (!controlsNotVisible ||
          isVideoFinished(_controller!.value) ||
          _wasLoading ||
          isLoading(_controller!.value)) {
        setState(() {
          // _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue) &&
              _betterPlayerController?.isLiveStream() == false) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(right: controllIconPadding),
        child: BetterPlayerMaterialVideoProgressBar(
          _controller,
          _betterPlayerController,
          onDragStart: () {
            _hideTimer?.cancel();
          },
          onDragEnd: () {
            _startHideTimer();
          },
          onTapDown: () {
            cancelAndRestartTimer();
          },
          colors: BetterPlayerProgressColors(
            playedColor: _controlsConfiguration.progressBarPlayedColor,
            handleColor: _controlsConfiguration.progressBarHandleColor,
            bufferedColor: _controlsConfiguration.progressBarBufferedColor,
            backgroundColor: _controlsConfiguration.progressBarBackgroundColor,
          ),
          duration: wasSeeking
              ? Duration(seconds: _latestSeconds! + _seekedSeconds!)
              : null,
        ),
      ),
    );
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return Container(
        color: _controlsConfiguration.controlBarColor,
        child: _controlsConfiguration.loadingWidget,
      );
    }

    return CircularProgressIndicator(
      valueColor:
          AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }
}
