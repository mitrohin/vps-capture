import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/models/judge_web_server_status.dart';
import '../../localization/app_localizations.dart';
import 'recorded_clip_index.dart';

class JudgeWebServer {
  JudgeWebServer(this._clipIndex);

  final RecordedClipIndex _clipIndex;
  final Set<HttpResponse> _eventClients = <HttpResponse>{};

  HttpServer? _server;
  JudgeWebSnapshot _snapshot = const JudgeWebSnapshot(languageCode: 'en');

  Future<JudgeWebServerStatus> start({
    required int port,
    required JudgeWebSnapshot snapshot,
  }) async {
    await stop();
    _snapshot = snapshot;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: false);
      final boundPort = _server!.port;
      unawaited(_listen(_server!));
      return JudgeWebServerStatus(
        isRunning: true,
        port: boundPort,
        urls: await _buildUrls(boundPort),
      );
    } catch (error) {
      return JudgeWebServerStatus(
        isRunning: false,
        port: port,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    for (final client in _eventClients.toList()) {
      await _closeEventClient(client);
    }
    _eventClients.clear();
    await server?.close(force: true);
  }

  Future<void> update(JudgeWebSnapshot snapshot) async {
    _snapshot = snapshot;
    await _broadcastSnapshot();
  }

  Future<void> _listen(HttpServer server) async {
    try {
      await for (final request in server) {
        unawaited(_handle(request));
      }
    } catch (_) {
      // Server was stopped.
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (path == '/' || path == '/index.html') {
      return _writeHtml(request.response);
    }
    if (path == '/api/state') {
      return _writeJson(request.response, _snapshot.toJson());
    }
    if (path == '/events') {
      return _openEventsStream(request.response);
    }
    if (path == '/video') {
      final clipId = request.uri.queryParameters['clipId'];
      if (clipId == null || clipId.isEmpty) {
        return _writeNotFound(request.response);
      }
      return _streamVideo(request, clipId);
    }
    return _writeNotFound(request.response);
  }

  Future<void> _writeHtml(HttpResponse response) async {
    response.headers.contentType = ContentType('text', 'html', charset: 'utf-8');
    response.write(_htmlDocument());
    await response.close();
  }

  Future<void> _writeJson(HttpResponse response, Map<String, dynamic> data) async {
    response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    response.write(jsonEncode(data));
    await response.close();
  }

  Future<void> _openEventsStream(HttpResponse response) async {
    response.statusCode = HttpStatus.ok;
    response.headers
      ..set(HttpHeaders.contentTypeHeader, 'text/event-stream; charset=utf-8')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache')
      ..set(HttpHeaders.connectionHeader, 'keep-alive')
      ..set('Access-Control-Allow-Origin', '*');
    _eventClients.add(response);
    response.add(utf8.encode('retry: 1500\n'));
    response.add(utf8.encode('data: ${jsonEncode(_snapshot.toJson())}\n\n'));
    await response.flush();
    response.done.whenComplete(() {
      _eventClients.remove(response);
    });
  }

  Future<void> _streamVideo(HttpRequest request, String clipId) async {
    final response = request.response;
    final entry = _clipIndex.entryByClipId(clipId);
    if (entry == null) {
      return _writeNotFound(response);
    }

    final file = File(entry.path);
    if (!await file.exists()) {
      return _writeNotFound(response);
    }

    final length = await file.length();
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    response.headers.contentType = ContentType('video', 'mp4');
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');

    if (rangeHeader == null || !rangeHeader.startsWith('bytes=')) {
      response.contentLength = length;
      await response.addStream(file.openRead());
      await response.close();
      return;
    }

    final range = parseRangeHeader(rangeHeader, length);
    if (range == null) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
      await response.close();
      return;
    }

    response.statusCode = HttpStatus.partialContent;
    response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes ${range.start}-${range.end}/$length',
    );
    response.contentLength = range.end - range.start + 1;
    await response.addStream(file.openRead(range.start, range.end + 1));
    await response.close();
  }

  Future<void> _broadcastSnapshot() async {
    if (_eventClients.isEmpty) {
      return;
    }

    final payload = 'data: ${jsonEncode(_snapshot.toJson())}\n\n';
    for (final client in _eventClients.toList()) {
      try {
        client.write(payload);
        await client.flush();
      } catch (_) {
        await _closeEventClient(client);
        _eventClients.remove(client);
      }
    }
  }

  Future<void> _closeEventClient(HttpResponse client) async {
    try {
      await client.close();
    } catch (_) {
      // Ignore already closed connections.
    }
  }

  Future<void> _writeNotFound(HttpResponse response) async {
    response.statusCode = HttpStatus.notFound;
    response.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
    response.write('Not found');
    await response.close();
  }

  Future<List<String>> _buildUrls(int port) async {
    final urls = <String>{'http://127.0.0.1:$port'};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final networkInterface in interfaces) {
        for (final address in networkInterface.addresses) {
          urls.add('http://${address.address}:$port');
        }
      }
    } catch (_) {
      // Best-effort only.
    }
    final sorted = urls.toList()..sort();
    return sorted;
  }

  String _htmlDocument() {
    return r'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>VPS Capture Judge Panel</title>
  <style>
    :root { color-scheme: dark; }
    body { margin: 0; font-family: Arial, sans-serif; background: #0e1116; color: #f4f7fb; }
    .shell { max-width: 1400px; margin: 0 auto; padding: 24px; }
    .topbar { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 16px; align-items: center; }
    .title h1 { margin: 0; font-size: 34px; }
    .title p { margin: 6px 0 0; color: #9fb0c6; }
    .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; margin-top: 20px; }
    .stat { background: #171c24; border: 1px solid #2a3442; border-radius: 18px; padding: 16px; }
    .stat strong { display: block; font-size: 28px; margin-top: 8px; }
    .toolbar { display: grid; grid-template-columns: 1fr minmax(170px, 220px) minmax(170px, 220px); gap: 12px; margin: 20px 0; width: 100%; }
    .toolbar input, .toolbar select { width: 100%; box-sizing: border-box; background: #171c24; color: #fff; border: 1px solid #334155; border-radius: 12px; padding: 12px 14px; font-size: 16px; }
    .list { display: grid; gap: 18px; }
    .thread-group h2 { margin: 0 0 10px; font-size: 22px; color: #d8e7f9; }
    .table { border: 1px solid #2d3748; border-radius: 14px; overflow: hidden; background: #121720; }
    .table-head, .table-row { display: grid; grid-template-columns: minmax(140px, 1.2fr) minmax(220px, 2fr) minmax(220px, 2fr) minmax(150px, 1fr) minmax(190px, auto); gap: 10px; align-items: center; padding: 10px 12px; }
    .table-head { background: #1a222d; font-size: 12px; text-transform: uppercase; color: #9fb0c6; font-weight: 700; letter-spacing: .04em; }
    .table-row { border-top: 1px solid #273142; font-size: 15px; }
    .table-row.done { background: rgba(15, 110, 72, 0.12); }
    .table-row.active { background: rgba(245, 158, 11, 0.12); }
    .table-row.postponed { background: rgba(107, 33, 71, 0.14); }
    .table-row.pending { background: rgba(51, 65, 85, 0.16); }
    .type-cell { display: inline-flex; align-items: center; gap: 8px; min-width: 0; }
    .type-box { width: 22px; height: 22px; border-radius: 4px; border: 1px solid transparent; display: inline-flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 800; }
    .fio { font-weight: 700; }
    .meta { color: #bdd0e5; min-width: 0; }
    .status { display: inline-flex; align-items: center; border-radius: 999px; padding: 4px 10px; font-size: 12px; font-weight: 700; width: fit-content; }
    .status.pending { background: #334155; }
    .status.active { background: #8a5a00; }
    .status.done { background: #0f6e48; }
    .status.postponed { background: #6b2147; }
    button { cursor: pointer; border: none; border-radius: 12px; padding: 12px 16px; font-size: 16px; font-weight: 700; }
    button.primary { background: #22c55e; color: #04120a; }
    button.primary .play { margin-right: 8px; }
    button.secondary { background: #334155; color: #fff; }
    button:disabled { opacity: .45; cursor: default; }
    .empty { text-align: center; padding: 56px 20px; background: #171c24; border: 1px dashed #334155; border-radius: 18px; color: #9fb0c6; }
    dialog { width: min(1100px, calc(100vw - 24px)); border: 1px solid #334155; border-radius: 20px; background: #0f131a; color: #fff; padding: 0; }
    dialog::backdrop { background: rgba(0, 0, 0, .72); }
    .dialog-head, .dialog-body { padding: 18px 20px; }
    .dialog-head { display: flex; justify-content: space-between; gap: 12px; border-bottom: 1px solid #233042; }
    .dialog-body video { width: 100%; max-height: 76vh; background: #000; border-radius: 14px; }
    .hint { color: #9fb0c6; font-size: 14px; }
    @media (max-width: 720px) {
      .shell { padding: 16px; }
      .name { font-size: 22px; }
      .title h1 { font-size: 28px; }
      .toolbar { grid-template-columns: 1fr; }
      .table { border: 0; background: transparent; }
      .table-head { display: none; }
      .table-row { display: grid; grid-template-columns: 1fr; gap: 8px; border: 1px solid #2d3748; border-radius: 14px; margin-bottom: 10px; background: #121720; }
      .table-row > div { display: flex; justify-content: space-between; gap: 10px; }
      .table-row > div::before { color: #9fb0c6; font-size: 12px; }
      .table-row > div:nth-child(1)::before { content: 'Вид'; }
      .table-row > div:nth-child(2)::before { content: 'ФИО'; }
      .table-row > div:nth-child(3)::before { content: 'Доп. инфо'; }
      .table-row > div:nth-child(4)::before { content: 'Статус'; }
    }
  </style>
</head>
<body>
  <div class="shell">
    <div class="topbar">
      <div class="title">
        <h1 id="page-title">Judge panel</h1>
        <p id="last-updated"></p>
      </div>
      <div class="hint" id="auto-refresh-hint"></div>
    </div>
    <section class="summary" id="summary"></section>
    <section class="toolbar">
      <input id="search" type="search" placeholder="Search">
      <select id="status-filter"></select>
      <select id="thread-filter"></select>
    </section>
    <section class="list" id="cards"></section>
  </div>

  <dialog id="player-dialog">
    <div class="dialog-head">
      <div>
        <div id="player-title" style="font-size:24px;font-weight:700"></div>
        <div id="player-meta" class="hint"></div>
      </div>
      <button id="player-close" class="secondary">Close</button>
    </div>
    <div class="dialog-body">
      <video id="player" controls preload="metadata"></video>
    </div>
  </dialog>

  <script>
    const POLL_INTERVAL_MS = 3000;
    const state = { snapshot: null, search: '', status: 'done', thread: 'all' };
    const summary = document.getElementById('summary');
    const cards = document.getElementById('cards');
    const search = document.getElementById('search');
    const statusFilter = document.getElementById('status-filter');
    const threadFilter = document.getElementById('thread-filter');
    const dialog = document.getElementById('player-dialog');
    const player = document.getElementById('player');
    const playerTitle = document.getElementById('player-title');
    const playerMeta = document.getElementById('player-meta');
    const playerClose = document.getElementById('player-close');
    const lastUpdated = document.getElementById('last-updated');
    const pageTitle = document.getElementById('page-title');
    const autoRefreshHint = document.getElementById('auto-refresh-hint');
    let refreshTimer = null;
    let eventsSource = null;
    let refreshInFlight = null;

    search.addEventListener('input', () => { state.search = search.value.trim().toLowerCase(); render(); });
    statusFilter.addEventListener('change', () => { state.status = statusFilter.value; render(); });
    threadFilter.addEventListener('change', () => { state.thread = threadFilter.value; render(); });
    playerClose.addEventListener('click', closePlayer);
    dialog.addEventListener('close', () => {
      player.pause();
      player.removeAttribute('src');
      player.load();
    });

    function closePlayer() {
      if (dialog.open) dialog.close();
    }

    async function refreshSnapshot() {
      if (refreshInFlight) return refreshInFlight;

      refreshInFlight = fetch('/api/state', { cache: 'no-store' })
        .then((response) => response.json())
        .then((snapshot) => {
          state.snapshot = snapshot;
          render();
          return snapshot;
        })
        .catch((error) => {
          console.error('Judge page refresh failed', error);
          throw error;
        })
        .finally(() => {
          refreshInFlight = null;
        });

      return refreshInFlight;
    }

    function schedulePolling() {
      if (refreshTimer) clearInterval(refreshTimer);
      refreshTimer = setInterval(() => {
        refreshSnapshot().catch(() => {});
      }, POLL_INTERVAL_MS);
    }

    function bindEvents() {
      if (eventsSource) eventsSource.close();
      eventsSource = new EventSource('/events');
      eventsSource.onmessage = (event) => {
        state.snapshot = JSON.parse(event.data);
        render();
      };
      eventsSource.onerror = () => {
        refreshSnapshot().catch(() => {});
      };
    }

    async function bootstrap() {
      await refreshSnapshot();
      bindEvents();
      schedulePolling();
    }

    function render() {
      const snapshot = state.snapshot;
      if (!snapshot) return;
      const t = snapshot.translations;
      document.documentElement.lang = snapshot.languageCode || 'en';
      document.title = `${t.judgePageTitle} — VPS Capture`;
      pageTitle.textContent = t.judgePageTitle;
      autoRefreshHint.textContent = t.judgeAutoRefreshHint;
      search.placeholder = t.judgeSearchPlaceholder;
      playerClose.textContent = t.close;
      lastUpdated.textContent = `${t.judgeLastUpdate}: ${formatDate(snapshot.generatedAt)}`;

      const statusOptions = [
        ['done', t.judgeStatusDoneOnly],
        ['active', t.judgeStatusActiveOnly],
        ['all', t.judgeStatusAll],
        ['pending', t.judgeStatusPendingOnly],
        ['postponed', t.judgeStatusPostponedOnly],
      ];
      statusFilter.innerHTML = statusOptions.map(([value, label]) => `<option value="${value}">${escapeHtml(label)}</option>`).join('');
      statusFilter.value = statusOptions.some(([value]) => value === state.status) ? state.status : 'done';

      const threadOptions = [['all', t.judgeThreadAll], ...snapshot.threads.map((thread) => [String(thread.value), thread.label])];
      threadFilter.innerHTML = threadOptions.map(([value, label]) => `<option value="${value}">${escapeHtml(label)}</option>`).join('');
      threadFilter.value = threadOptions.some(([value]) => value === state.thread) ? state.thread : 'all';

      summary.innerHTML = [
        [t.judgeStatDone, snapshot.stats.done],
        [t.judgeStatActive, snapshot.stats.active],
        [t.judgeStatPending, snapshot.stats.pending],
        [t.judgeStatReplays, snapshot.stats.withReplay],
      ].map(([label, value]) => `<div class="stat"><span>${escapeHtml(label)}</span><strong>${value}</strong></div>`).join('');

      const visible = snapshot.participants
        .filter((participant) => {
          if (state.status !== 'all' && participant.status !== state.status) return false;
          if (state.thread !== 'all' && String(participant.threadIndex ?? '') !== state.thread) return false;
          if (!state.search) return true;
          const haystack = `${participant.fio} ${participant.city} ${participant.apparatus ?? ''}`.toLowerCase();
          return haystack.includes(state.search);
        });

      if (!visible.length) {
        cards.innerHTML = `<div class="empty">${escapeHtml(t.judgeEmpty)}</div>`;
        return;
      }

      const groups = [];
      const groupByThread = new Map();
      visible.forEach((participant) => {
        const key = String(participant.threadIndex ?? 'no-thread');
        if (!groupByThread.has(key)) {
          groupByThread.set(key, {
            key,
            label: participant.threadIndex != null ? `Поток ${participant.threadIndex + 1}` : (participant.threadLabel || 'Поток —'),
            items: [],
          });
          groups.push(groupByThread.get(key));
        }
        groupByThread.get(key).items.push(participant);
      });

      cards.innerHTML = groups.map((group) => `
        <section class="thread-group">
          <h2>${escapeHtml(group.label)}</h2>
          <div class="table">
            <div class="table-head">
              <div>Вид</div>
              <div>ФИО</div>
              <div>Доп. информация</div>
              <div>Статус</div>
              <div></div>
            </div>
            ${group.items.map((participant) => `
              <div class="table-row ${participant.status}">
                <div class="type-cell">
                  ${renderTypeCell(participant)}
                </div>
                <div class="fio">${escapeHtml(participant.fio)}</div>
                <div class="meta">${escapeHtml([participant.city, participant.apparatus, participant.startedAtLabel ? `${t.judgeStartedAt}: ${participant.startedAtLabel}` : null].filter(Boolean).join(' • '))}</div>
                <div><span class="status ${participant.status}">${escapeHtml(participant.statusLabel)}</span></div>
                <div>
                  <button class="primary" ${participant.clipId ? '' : 'disabled'} data-clip-id="${participant.clipId ?? ''}" data-title="${escapeHtmlAttr(participant.fio)}" data-meta="${escapeHtmlAttr([participant.city, participant.apparatus, participant.threadLabel, participant.typeLabel].filter(Boolean).join(' • '))}">
                    <span class="play">▶</span>${escapeHtml(t.judgeOpenReplay)}
                  </button>
                </div>
              </div>
            `).join('')}
          </div>
        </section>
      `).join('');

      cards.querySelectorAll('button[data-clip-id]').forEach((button) => {
        button.addEventListener('click', () => {
          const clipId = button.dataset.clipId;
          if (!clipId) return;
          playerTitle.textContent = button.dataset.title || '';
          playerMeta.textContent = button.dataset.meta || '';
          player.src = `/video?clipId=${encodeURIComponent(clipId)}`;
          if (!dialog.open) dialog.showModal();
          player.play().catch(() => {});
        });
      });
    }

    function formatDate(value) {
      if (!value) return '—';
      const date = new Date(value);
      return new Intl.DateTimeFormat(state.snapshot.languageCode || 'en', {
        year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit'
      }).format(date);
    }

    function escapeHtml(value) {
      return String(value)
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
    }

    function escapeHtmlAttr(value) {
      return escapeHtml(value).replaceAll('`', '&#96;');
    }

    function getTypeColor(typeIndex) {
      switch (Number(typeIndex)) {
        case 1: return '#4CAF50';
        case 2: return '#2196F3';
        case 3: return '#FF9800';
        case 4: return '#E91E63';
        case 5: return '#003C97';
        case 6: return '#00FFBF';
        case 7: return '#7700FF';
        case 8: return '#FF4985';
        default: return '#9C27B0';
      }
    }

    function renderTypeCell(participant) {
      if (participant.typeIndex == null) return participant.typeLabel ? escapeHtml(participant.typeLabel) : '—';
      const color = getTypeColor(participant.typeIndex);
      const label = participant.typeLabel || `Вид ${participant.typeIndex}`;
      return `<span class="type-box" style="background:${color}22;border-color:${color};color:${color}">${participant.typeIndex}</span><span>${escapeHtml(label)}</span>`;
    }

    bootstrap();
  </script>
</body>
</html>''';
  }
}

JudgeWebSnapshot buildJudgeWebSnapshot({
  required String languageCode,
  required List<JudgeWebParticipant> participants,
}) {
  return JudgeWebSnapshot.build(
    languageCode: languageCode,
    participants: participants,
  );
}

class JudgeWebSnapshot {
  const JudgeWebSnapshot({
    required this.languageCode,
    this.generatedAt,
    this.participants = const [],
  }) : translations = const {};

  JudgeWebSnapshot.build({
    required this.languageCode,
    required this.participants,
    DateTime? generatedAt,
  })  : generatedAt = generatedAt ?? DateTime.now().toUtc(),
        translations = _translations(languageCode);

  final String languageCode;
  final DateTime? generatedAt;
  final List<JudgeWebParticipant> participants;
  final Map<String, String> translations;

  Map<String, dynamic> toJson() {
    final threads = participants
        .where((participant) => participant.threadIndex != null)
        .map((participant) => participant.threadIndex!)
        .toSet()
        .toList()
      ..sort();

    final stats = <String, int>{
      'pending': participants.where((participant) => participant.status == 'pending').length,
      'active': participants.where((participant) => participant.status == 'active').length,
      'done': participants.where((participant) => participant.status == 'done').length,
      'postponed': participants.where((participant) => participant.status == 'postponed').length,
      'withReplay': participants.where((participant) => participant.clipId != null).length,
    };

    return {
      'languageCode': languageCode,
      'generatedAt': generatedAt?.toIso8601String(),
      'translations': translations,
      'stats': stats,
      'threads': threads
          .map((thread) => {
                'value': thread,
                'label': 'T${thread + 1}',
              })
          .toList(growable: false),
      'participants': participants.map((participant) => participant.toJson()).toList(growable: false),
    };
  }

  static Map<String, String> _translations(String languageCode) {
    const keys = [
      'judgePageTitle',
      'judgeAutoRefreshHint',
      'judgeSearchPlaceholder',
      'judgeStatusDoneOnly',
      'judgeStatusActiveOnly',
      'judgeStatusAll',
      'judgeStatusPendingOnly',
      'judgeStatusPostponedOnly',
      'judgeThreadAll',
      'judgeStatDone',
      'judgeStatActive',
      'judgeStatPending',
      'judgeStatReplays',
      'judgeEmpty',
      'judgeOpenReplay',
      'judgeReplayMissing',
      'judgeStartedAt',
      'judgeLastUpdate',
      'close',
    ];

    return {
      for (final key in keys) key: AppLocalizations.tr(languageCode, key),
    };
  }
}

class JudgeWebParticipant {
  const JudgeWebParticipant({
    required this.id,
    required this.fio,
    required this.city,
    required this.status,
    required this.statusLabel,
    this.apparatus,
    this.clipId,
    this.startedAt,
    this.startedAtLabel,
    this.threadIndex,
    this.typeIndex,
    this.threadLabel,
    this.typeLabel,
  });

  final String id;
  final String fio;
  final String city;
  final String? apparatus;
  final String status;
  final String statusLabel;
  final String? clipId;
  final DateTime? startedAt;
  final String? startedAtLabel;
  final int? threadIndex;
  final int? typeIndex;
  final String? threadLabel;
  final String? typeLabel;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fio': fio,
        'city': city,
        'apparatus': apparatus,
        'status': status,
        'statusLabel': statusLabel,
        'clipId': clipId,
        'startedAt': startedAt?.toIso8601String(),
        'startedAtLabel': startedAtLabel,
        'threadIndex': threadIndex,
        'typeIndex': typeIndex,
        'threadLabel': threadLabel,
        'typeLabel': typeLabel,
      };
}

class ByteRange {
  const ByteRange({required this.start, required this.end});

  final int start;
  final int end;
}

ByteRange? parseRangeHeader(String header, int fileLength) {
  final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(header);
  if (match == null) {
    return null;
  }

  final startGroup = match.group(1);
  final endGroup = match.group(2);
  int start;
  int end;

  if ((startGroup == null || startGroup.isEmpty) && (endGroup == null || endGroup.isEmpty)) {
    return null;
  }

  if (startGroup == null || startGroup.isEmpty) {
    final suffixLength = int.tryParse(endGroup!);
    if (suffixLength == null || suffixLength <= 0 || fileLength <= 0) {
      return null;
    }
    start = (fileLength - suffixLength).clamp(0, fileLength - 1);
    end = fileLength - 1;
  } else {
    start = int.tryParse(startGroup) ?? -1;
    end = int.tryParse(endGroup ?? '') ?? (fileLength - 1);
    if (start < 0 || start >= fileLength) {
      return null;
    }
    if (end >= fileLength) {
      end = fileLength - 1;
    }
    if (end < start) {
      return null;
    }
  }

  return ByteRange(start: start, end: end);
}
