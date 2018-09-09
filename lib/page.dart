import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers/audio_cache.dart';

class JukephonePage extends StatefulWidget {
  JukephonePage({Key key, this.origin}) : super(key: key);

  final Uri origin;

  @override
  _JukephonePageState createState() => new _JukephonePageState();
}

final Uri _defaultSong = Uri(
  scheme: 'file',
  host: 'assets',
  path: 'default.mp3',
);

class _JukephonePageState extends State<JukephonePage> {
  Uri _location;
  Uri _song;
  bool _paused = false;

  AudioPlayer _audioPlayer;
  AudioCache _audioCache;

  _JukephonePageState() : super() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.STOP);
    _audioCache = AudioCache(fixedPlayer: _audioPlayer);
    _audioCache.load('default.mp3');
  }

  _requestLocation() async {
    var response = await _retries(() => post(widget.origin));

    _raiseHttpStatus(response);

    var location = Uri.parse(response.headers['location']);
    setState(() { _location = location; });
  }

  _requestSong() async {
    var response = await _retries(() => get(_location));

    _raiseHttpStatus(response);

    var song = _parseSongResponse(response);
    _play(song);
  }

  _requestNextSong() async {
    var response = await _retries(() => post(_location.toString() + '/next'));
    _raiseHttpStatus(response);

    var song = _parseSongResponse(response);
    _play(song);
  }

  _parseSongResponse(Response response) {
    if (response.statusCode == 204) {
      return _defaultSong;
    } else {
      return Uri.parse(response.headers['location']);
    }
  }

  _play(Uri song) async {
    print(song);
    if (song == _defaultSong) {
      _audioCache.play('default.mp3');
    } else {
      var result = await _audioPlayer.play(song.toString());
      if (result != 1) return _next();
    }
    setState(() {
      _song = song;
      _paused = false;
    });
  }

  _pause() {
    _audioPlayer.pause();
    setState(() { _paused = true; });
  }

  _resume() {
    _audioPlayer.resume();
    setState(() { _paused = false; });
  }

  _replay() {
    _audioPlayer.seek(Duration.zero);
    if (_paused) _resume();
  }

  _next() {
    _audioPlayer.stop();
    setState(() { _song = null; });
    _requestNextSong();
  }

  _getFloatingActionButton(BuildContext context) {
    if (_song == null) return null;

    if (_paused) {
      return FloatingActionButton(
        child: Icon(Icons.play_arrow, semanticLabel: 'play'),
        onPressed: _resume,
      );
    } else {
      return FloatingActionButton(
        child: Icon(Icons.pause, semanticLabel: 'pause'),
        onPressed: _pause,
      );
    }
  }

  _getAppBarActions(BuildContext context) {
    if (_song == null) return <Widget>[];

    return [
      IconButton(
        icon: Icon(Icons.skip_previous, semanticLabel: 'replay'),
        onPressed: _replay,
      ),
      IconButton(
        icon: Icon(Icons.skip_next, semanticLabel: 'next'),
        onPressed: _next,
      ),
    ];
  }

  _getBodyContent(BuildContext context) {
    if (_location == null) return CircularProgressIndicator();

    return QrImage(
      data: _location.toString() + '.html',
      padding: EdgeInsets.all(48.0),
      foregroundColor: Theme.of(context).primaryColorDark,
    );
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer.completionHandler = _next;
    () async {
      await _requestLocation();
      await _requestSong();
    } ();
  }

  @override
  void dispose() {
    super.dispose();
    _audioPlayer.completionHandler = null;
  }

  @override
  Widget build(BuildContext context) {
    var appBarActions = _getAppBarActions(context);
    var bodyContent = _getBodyContent(context);
    var floatingActionButton = _getFloatingActionButton(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Jukephone'),
        actions: appBarActions,
      ),
      body: Center(child: bodyContent),
      floatingActionButton: floatingActionButton,
    );
  }
}

_raiseHttpStatus(Response response) {
  if (response.statusCode >= 400) {
    var message = '${response.statusCode} ${response.reasonPhrase}';
    throw ClientException(message, response.request.url);
  }
  return response;
}

_retries<T>(Future<T> Function() futureFunction, [int count = 10]) async {
  for (var i = 1; i <= count; i += 1) {
    try {
      return await futureFunction();
    } catch (error, stack) {
      print(error);
      print(stack);
      print('Will retry');
      if (i == count) rethrow;
    }
  }
}
