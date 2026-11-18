import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlashAlertApp());
}

const _white = Color(0xFFF4F8FF);
const _muted = Color(0xFFB3C2D5);
const _aqua = Color(0xFF8CEAF2);
const _violet = Color(0xFFAE9CFF);

class FlashAlertApp extends StatelessWidget {
  const FlashAlertApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FlashAlert',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF090E1C),
          colorScheme: ColorScheme.fromSeed(
            seedColor: _aqua,
            brightness: Brightness.dark,
          ),
          textTheme: ThemeData.dark().textTheme.apply(
                bodyColor: _white,
                displayColor: _white,
              ),
        ),
        home: const FlashHome(),
      );
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 26,
    this.blur = 15,
    this.opacity = .09,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double opacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: opacity + .055),
                      Colors.white.withValues(alpha: opacity * .55),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: .19)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .13),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
}

class _GradientBackdrop extends StatelessWidget {
  const _GradientBackdrop();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF151E39), Color(0xFF12132B), Color(0xFF071D2B)],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Positioned(
              top: -115,
              left: -130,
              child: _glow(const Color(0xFF6C9BFF), 360),
            ),
            Positioned(
              top: 230,
              right: -145,
              child: _glow(const Color(0xFF966BE6), 330),
            ),
            Positioned(
              bottom: -150,
              left: -90,
              child: _glow(const Color(0xFF0BC6BD), 350),
            ),
          ],
        ),
      );

  static Widget _glow(Color color, double diameter) => Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: .35),
            color.withValues(alpha: .09),
            Colors.transparent,
          ]),
        ),
      );
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.busy = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: GlassSurface(
          radius: 20,
          padding: EdgeInsets.zero,
          opacity: primary ? .18 : .06,
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            decoration: primary
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(colors: [
                      _aqua.withValues(alpha: .22),
                      _violet.withValues(alpha: .22),
                    ]),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (busy)
                const SizedBox(
                  height: 19,
                  width: 19,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _white),
                )
              else
                Icon(icon, size: 21, color: primary ? _aqua : _white),
              const SizedBox(width: 10),
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
}

class _GlassSwitch extends StatelessWidget {
  const _GlassSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: _aqua.withValues(alpha: .8),
        activeThumbColor: const Color(0xFF173142),
        inactiveTrackColor: Colors.white.withValues(alpha: .14),
        inactiveThumbColor: _muted,
      );
}

class FlashHome extends StatefulWidget {
  const FlashHome({super.key});
  @override
  State<FlashHome> createState() => _FlashHomeState();
}

class _FlashHomeState extends State<FlashHome> with WidgetsBindingObserver {
  static const channel = MethodChannel('com.flashalert.flash/torch');
  bool calls = false, notifications = false, busy = false;
  bool cameraGranted = false, phoneGranted = false, listenerGranted = false;
  bool listenerRunning = false, batteryUnrestricted = false;
  int lastNotificationSeen = 0;
  bool loading = true;
  double onMs = 200, offMs = 200, callOnMs = 200, callOffMs = 200;
  int count = 5;
  String blinkPattern = 'normal';
  bool quietEnabled = false, quietCalls = false;
  bool batterySavingNotifications = true;
  int quietStart = 23 * 60, quietEnd = 7 * 60;
  final Set<String> ignored = {};
  List<Map<String, String>> apps = [];
  String message = 'Проверь настройки и разрешения';
  int page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _status();
  }

  Future<void> _load() async {
    try {
      final p = await channel.invokeMapMethod<String, dynamic>('getSettings') ?? {};
      final list = await channel.invokeListMethod<dynamic>('getApps') ?? [];
      if (!mounted) return;
      setState(() {
        calls = p['calls'] == true;
        notifications = p['notifications'] == true;
        onMs = ((p['onMs'] as num?) ?? 200).toDouble().clamp(20.0, 600.0);
        offMs = ((p['offMs'] as num?) ?? 200).toDouble().clamp(20.0, 600.0);
        callOnMs = ((p['callOnMs'] as num?) ?? 200).toDouble().clamp(20.0, 600.0);
        callOffMs = ((p['callOffMs'] as num?) ?? 200).toDouble().clamp(20.0, 600.0);
        count = ((p['count'] as num?) ?? 5).toInt().clamp(1, 10);
        final pattern = (p['pattern'] ?? 'normal').toString();
        blinkPattern = ['normal', 'double', 'fast'].contains(pattern) ? pattern : 'normal';
        quietEnabled = p['quietEnabled'] == true;
        batterySavingNotifications = p['batterySavingNotifications'] != false;
        quietCalls = p['quietCalls'] == true;
        quietStart = ((p['quietStart'] as num?) ?? 1380).toInt().clamp(0, 1439);
        quietEnd = ((p['quietEnd'] as num?) ?? 420).toInt().clamp(0, 1439);
        ignored
          ..clear()
          ..addAll((p['ignored'] as List? ?? []).whereType<String>());
        apps = list.whereType<Map>().map((e) => {
              'name': (e['name'] ?? '').toString(),
              'package': (e['package'] ?? '').toString(),
            }).toList();
      });
      await _status();
    } catch (e) {
      if (mounted) _showMessage('Не удалось загрузить настройки: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _status() async {
    try {
      final p = await channel.invokeMapMethod<String, dynamic>('status') ?? {};
      if (!mounted) return;
      setState(() {
        cameraGranted = p['camera'] == true;
        phoneGranted = p['phone'] == true;
        listenerGranted = p['listener'] == true;
        listenerRunning = p['listenerRunning'] == true;
        batteryUnrestricted = p['batteryUnrestricted'] == true;
        lastNotificationSeen = (p['lastNotificationSeen'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  void _showMessage(String text) {
    if (!mounted) return;
    setState(() => message = text);
  }

  Future<void> _save() async {
    try {
      await channel.invokeMethod('saveSettings', {
        'calls': calls,
        'notifications': notifications,
        'onMs': onMs.round(),
        'offMs': offMs.round(),
        'callOnMs': callOnMs.round(),
        'callOffMs': callOffMs.round(),
        'count': count,
        'pattern': blinkPattern,
        'quietEnabled': quietEnabled,
        'batterySavingNotifications': batterySavingNotifications,
        'quietCalls': quietCalls,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
        'ignored': ignored.toList(),
      });
    } on PlatformException catch (e) {
      _showMessage('Ошибка сохранения: ${e.message ?? e.code}');
    }
  }

  Future<void> _test() async {
    if (busy) return;
    setState(() { busy = true; message = 'Проверяем вспышку…'; });
    try {
      await channel.invokeMethod('blink', {
        'onMs': onMs.round(),
        'offMs': offMs.round(),
        'count': count,
        'pattern': blinkPattern,
      });
      _showMessage('Проверка завершена');
    } on PlatformException catch (e) {
      _showMessage('Ошибка вспышки: ${e.message ?? e.code}');
    } catch (e) {
      _showMessage('Ошибка: $e');
    } finally {
      if (mounted) setState(() => busy = false);
      await _status();
    }
  }

  Future<void> _invoke(String method) async {
    try {
      await channel.invokeMethod(method);
      await _status();
    } on PlatformException catch (e) {
      _showMessage('Ошибка: ${e.message ?? e.code}');
    }
  }

  Widget _sectionHeader(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 12, top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  letterSpacing: -.5)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13)),
        ]),
      );

  Widget _switchRow(IconData icon, String label, String detail, bool value,
          ValueChanged<bool> onChanged, {Color tint = _aqua}) =>
      Row(children: [
        _iconBubble(icon, tint),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(fontSize: 12, color: _muted)),
          ]),
        ),
        _GlassSwitch(value: value, onChanged: onChanged),
      ]);

  Widget _iconBubble(IconData icon, Color tint) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: tint.withValues(alpha: .14),
          border: Border.all(color: tint.withValues(alpha: .18)),
        ),
        child: Icon(icon, color: tint, size: 22),
      );

  Widget _sliderTile(String label, double value, ValueChanged<double> changed) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 14, color: _white))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: .11),
            ),
            child: Text('${value.round()} мс',
                style: const TextStyle(fontWeight: FontWeight.w700, color: _aqua)),
          ),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            activeTrackColor: _aqua,
            inactiveTrackColor: Colors.white.withValues(alpha: .16),
            thumbColor: _white,
            overlayColor: _aqua.withValues(alpha: .12),
            valueIndicatorColor: const Color(0xFF26425E),
          ),
          child: Slider(
            min: 20,
            max: 600,
            divisions: 29,
            value: value,
            label: '${value.round()} мс',
            onChanged: (v) { setState(() => changed(v)); _save(); },
          ),
        ),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('20 мс', style: TextStyle(color: _muted, fontSize: 11)),
          Text('600 мс', style: TextStyle(color: _muted, fontSize: 11)),
        ]),
      ]);

  String _clockText(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  Future<void> _pickQuietTime(bool start) async {
    final minutes = start ? quietStart : quietEnd;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _aqua,
            onPrimary: Color(0xFF111827),
            surface: Color(0xFF17243B),
            onSurface: _white,
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (start) { quietStart = selected.hour * 60 + selected.minute; }
      else { quietEnd = selected.hour * 60 + selected.minute; }
    });
    await _save();
  }

  Widget _patternPicker() => GlassSurface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Режим мигания',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text('Применяется к звонкам, уведомлениям и тесту',
              style: TextStyle(fontSize: 12, color: _muted)),
          const SizedBox(height: 15),
          for (final entry in <(String, String, String)>[
            ('normal', 'Обычный', 'Ровные интервалы'),
            ('double', 'Двойной', 'Две вспышки, затем небольшая пауза'),
            ('fast', 'Быстрый', 'Короткие вспышки и короткие паузы'),
          ])
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: _aqua,
              title: Text(entry.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(entry.$3, style: const TextStyle(color: _muted, fontSize: 11)),
              value: entry.$1,
              groupValue: blinkPattern,
              onChanged: (value) {
                if (value == null) return;
                setState(() => blinkPattern = value);
                _save();
              },
            ),
        ]),
      );

  Widget _quietHoursCard() => GlassSurface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _switchRow(Icons.bedtime_outlined, 'Тихие часы',
              'Без миганий от уведомлений', quietEnabled, (v) {
            setState(() => quietEnabled = v); _save();
          }),
          const Divider(height: 28, color: Color(0x22FFFFFF)),
          Row(children: [
            Expanded(child: _timeChip('Начало', _clockText(quietStart), () => _pickQuietTime(true))),
            const SizedBox(width: 12),
            Expanded(child: _timeChip('Конец', _clockText(quietEnd), () => _pickQuietTime(false))),
          ]),
          const SizedBox(height: 10),
          _switchRow(Icons.call_end_outlined, 'Отключать и звонки',
              'Во время тихих часов', quietCalls, (v) {
            setState(() => quietCalls = v); _save();
          }),
          const SizedBox(height: 7),
          const Text('Одинаковое начало и конец означают круглосуточную тишину. '
              'Тест вспышки остаётся доступен. Время берётся с телефона.',
              style: TextStyle(color: _muted, fontSize: 11, height: 1.5)),
        ]),
      );

  Widget _timeChip(String title, String time, VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: Colors.white.withValues(alpha: .07),
            border: Border.all(color: Colors.white.withValues(alpha: .17)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(time, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _aqua)),
          ]),
        ),
      );

  Widget _permissionRow(IconData icon, String label, bool ok, String action,
      VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          _iconBubble(icon, ok ? _aqua : const Color(0xFFFFC38A)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(ok ? 'Разрешено' : 'Нужно разрешение',
                style: TextStyle(fontSize: 12,
                    color: ok ? _aqua : const Color(0xFFFFC38A))),
          ])),
          if (ok) const Icon(Icons.check_circle_rounded, color: _aqua)
          else TextButton(onPressed: onTap, child: Text(action)),
        ]),
      );

  Widget _homePage() {
    final ready = cameraGranted && phoneGranted && listenerGranted;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GlassSurface(
        radius: 34,
        opacity: .12,
        padding: const EdgeInsets.fromLTRB(22, 25, 22, 23),
        child: Column(children: [
          Container(
            width: 82, height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                _aqua.withValues(alpha: .3),
                _violet.withValues(alpha: .24),
              ]),
              border: Border.all(color: Colors.white.withValues(alpha: .3)),
              boxShadow: [BoxShadow(color: _aqua.withValues(alpha: .15), blurRadius: 35)],
            ),
            child: const Icon(Icons.bolt_rounded, size: 45, color: _white),
          ),
          const SizedBox(height: 17),
          const Text('Свет, который замечают',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800,
                  letterSpacing: -.5)),
          const SizedBox(height: 8),
          const Text('Входящие звонки и уведомления\nсо световым сигналом',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: (ready ? _aqua : const Color(0xFFFFC38A)).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ready ? Icons.verified_rounded : Icons.info_outline_rounded,
                  size: 16, color: ready ? _aqua : const Color(0xFFFFC38A)),
              const SizedBox(width: 7),
              Text(ready ? 'Основные разрешения готовы' : 'Проверь разрешения',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12,
                      color: ready ? _aqua : const Color(0xFFFFC38A))),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      GlassSurface(child: Column(children: [
        _switchRow(Icons.call_rounded, 'Входящие звонки',
            'Мигание во время вызова', calls, (v) {
          setState(() => calls = v); _save();
        }),
        const Divider(height: 26, color: Color(0x22FFFFFF)),
        _switchRow(Icons.notifications_active_rounded, 'Уведомления',
            'Сигнал при новых событиях', notifications, (v) {
          setState(() => notifications = v); _save();
        }, tint: _violet),
      ])),
      const SizedBox(height: 18),
      _GlassButton(label: busy ? 'Проверка…' : 'Проверить вспышку',
          icon: Icons.flash_on_rounded, onPressed: busy ? null : _test,
          primary: true, busy: busy),
      const SizedBox(height: 20),
      _sectionHeader('Быстрые настройки', 'Выбери параметры для каждого события'),
      _navCard(Icons.call_outlined, 'Настройки звонков',
          'Скорость, режим и пауза', 1, _aqua),
      const SizedBox(height: 10),
      _navCard(Icons.notifications_none_rounded, 'Настройки уведомлений',
          'Режим, тихие часы и фильтры', 2, _violet),
      const SizedBox(height: 10),
      _navCard(Icons.shield_outlined, 'Разрешения Android',
          'Доступ и работа в фоне', 3, const Color(0xFFFFC38A)),
    ]);
  }

  Widget _navCard(IconData icon, String title, String subtitle, int to, Color tint) =>
      GlassSurface(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 17),
        radius: 22,
        onTap: () => setState(() => page = to),
        child: Row(children: [
          _iconBubble(icon, tint),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ]),
      );

  Widget _callPage() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sectionHeader('Входящие звонки', 'Отдельный ритм светового сигнала'),
        GlassSurface(child: Column(children: [
          _switchRow(Icons.call_rounded, 'Мигать при звонке',
              'Останавливается при ответе или сбросе', calls, (v) {
            setState(() => calls = v); _save();
          }),
          const Divider(height: 31, color: Color(0x22FFFFFF)),
          _sliderTile('Длительность вспышки', callOnMs, (v) => callOnMs = v),
          const SizedBox(height: 17),
          _sliderTile('Пауза между вспышками', callOffMs, (v) => callOffMs = v),
        ])),
        const SizedBox(height: 14),
        _patternPicker(),
        const SizedBox(height: 14),
        GlassSurface(opacity: .045, child: const Row(children: [
          Icon(Icons.thermostat_outlined, color: _aqua),
          SizedBox(width: 12),
          Expanded(child: Text('Для защиты светодиода мигание при звонке ограничено двумя минутами.',
              style: TextStyle(fontSize: 12, color: _muted, height: 1.5))),
        ])),
      ]);

  Widget _notificationPage() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Уведомления', 'Настрой световой сигнал под себя'),
        GlassSurface(child: Column(children: [
          _switchRow(Icons.notifications_active_outlined, 'Мигать при уведомлениях',
              'Новые сообщения и события', notifications, (v) {
            setState(() => notifications = v); _save();
          }, tint: _violet),
          const Divider(height: 31, color: Color(0x22FFFFFF)),
          _sliderTile('Длительность вспышки', onMs, (v) => onMs = v),
          const SizedBox(height: 17),
          _sliderTile('Пауза между вспышками', offMs, (v) => offMs = v),
          const SizedBox(height: 21),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Количество вспышек', style: TextStyle(fontSize: 14)),
            Text('$count', style: const TextStyle(fontSize: 16,
                color: _aqua, fontWeight: FontWeight.w800)),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
                activeTrackColor: _violet,
                inactiveTrackColor: Colors.white.withValues(alpha: .16),
                thumbColor: _white),
            child: Slider(
              min: 1, max: 10, divisions: 9, value: count.toDouble(),
              label: '$count',
              onChanged: (v) { setState(() => count = v.round()); _save(); },
            ),
          ),
          const Divider(height: 26, color: Color(0x22FFFFFF)),
          InkWell(
            onTap: _showApps,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                _iconBubble(Icons.filter_alt_outlined, _violet),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Исключения приложений',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Игнорируются: ${ignored.length}',
                      style: const TextStyle(color: _muted, fontSize: 12)),
                ])),
                const Icon(Icons.chevron_right_rounded, color: _muted),
              ]),
            ),
          ),
        ])),
        const SizedBox(height: 15),
        _quietHoursCard(),
        const SizedBox(height: 15),
        GlassSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Защита и экономия энергии',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          _switchRow(Icons.battery_saver_outlined, 'Беречь низкий заряд',
              'Не мигать при уведомлениях при 15% и ниже, если телефон не заряжается',
              batterySavingNotifications, (v) {
            setState(() => batterySavingNotifications = v); _save();
          }, tint: _aqua),
          const SizedBox(height: 5),
          const Text('Между сериями уведомлений — минимум 3 секунды. '
              'При серьёзном перегреве по данным Android вспышка останавливается. '
              'Звонки сохраняют ограничение в 120 секунд.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.5)),
        ])),
        const SizedBox(height: 15),
        _GlassButton(label: busy ? 'Проверка…' : 'Тест уведомления',
            icon: Icons.bolt_rounded, onPressed: busy ? null : _test,
            busy: busy),
        const SizedBox(height: 10),
        const Text('Кнопка проверяет саму вспышку с параметрами уведомлений, '
            'но не имитирует системное уведомление.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 11, height: 1.5)),
      ]);

  String _formatSeen(int millis) {
    final t = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  Widget _diagnosticLine(String label, String value, bool ok) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle_outline : Icons.info_outline,
            size: 17, color: ok ? _aqua : const Color(0xFFFFC38A)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: _muted, fontSize: 12)),
        ])),
      ]);

  Widget _permissionsPage() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('Разрешения', 'Для звонков и уведомлений нужны доступы Android'),
          GlassSurface(child: Column(children: [
            _permissionRow(Icons.flash_on_rounded, 'Камера / вспышка',
                cameraGranted, 'Разрешить', () => _invoke('requestCamera')),
            const Divider(color: Color(0x22FFFFFF)),
            _permissionRow(Icons.phone_android_rounded, 'Состояние телефона',
                phoneGranted, 'Разрешить', () => _invoke('requestPhone')),
            const Divider(color: Color(0x22FFFFFF)),
            _permissionRow(Icons.notifications_rounded, 'Доступ к уведомлениям',
                listenerGranted, 'Открыть', () => _invoke('openNotificationAccess')),
          ])),
          const SizedBox(height: 15),
          GlassSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Диагностика фоновой работы',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _diagnosticLine('Служба уведомлений',
                !listenerGranted ? 'Нет системного доступа' :
                listenerRunning ? 'Подключена' : 'Не подключена',
                listenerRunning),
            const SizedBox(height: 9),
            _diagnosticLine('Оптимизация батареи',
                batteryUnrestricted ? 'Без ограничений Android' : 'Могут действовать ограничения',
                batteryUnrestricted),
            const SizedBox(height: 9),
            _diagnosticLine('Последнее замеченное уведомление',
                lastNotificationSeen == 0 ? 'Пока нет событий' :
                _formatSeen(lastNotificationSeen), lastNotificationSeen > 0),
            const SizedBox(height: 15),
            _GlassButton(label: 'Обновить диагностику',
                icon: Icons.refresh_rounded, onPressed: _status),
          ])),
          const SizedBox(height: 15),
          _GlassButton(label: 'Настройки батареи Android',
              icon: Icons.battery_saver_outlined,
              onPressed: () => _invoke('openBatterySettings')),
          const SizedBox(height: 15),
          GlassSurface(opacity: .055, child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Для TECNO / HiOS',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: 9),
              Text('Разреши автозапуск и работу FlashAlert в фоне в настройках HiOS / Phone Master. '
                  'После принудительной остановки приложения Android может перестать доставлять события. '
                  'Работу при блокировке экрана нужно проверить отдельно.',
                  style: TextStyle(fontSize: 12, height: 1.6, color: _muted)),
            ],
          )),
        ],
      );

  Future<void> _showApps() async {
    String query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, update) {
        final filtered = apps.where((a) =>
            '${a['name']} ${a['package']}'.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .78,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              child: Stack(children: [
                const Positioned.fill(child: _GradientBackdrop()),
                Positioned.fill(child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(color: const Color(0xFF121A31).withValues(alpha: .74)),
                )),
                SafeArea(top: false, child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Column(children: [
                    Container(height: 4, width: 42, decoration: BoxDecoration(
                      color: Colors.white38, borderRadius: BorderRadius.circular(20))),
                    const SizedBox(height: 17),
                    const Text('Исключения приложений',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    const Text('Отмеченные приложения не вызывают вспышку',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, fontSize: 12)),
                    const SizedBox(height: 16),
                    GlassSurface(
                      radius: 18, blur: 10,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded, color: _muted),
                          border: InputBorder.none,
                          hintText: 'Найти приложение',
                          hintStyle: TextStyle(color: _muted),
                        ),
                        onChanged: (v) => update(() => query = v),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: filtered.isEmpty
                        ? const Center(child: Text('Приложения не найдены',
                            style: TextStyle(color: _muted)))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, index) {
                              final app = filtered[index];
                              final pkg = app['package'] ?? '';
                              return CheckboxListTile(
                                activeColor: _aqua,
                                checkColor: const Color(0xFF101827),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 3),
                                title: Text(app['name'] ?? pkg,
                                    style: const TextStyle(fontSize: 14)),
                                subtitle: Text(pkg, maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: _muted)),
                                value: ignored.contains(pkg),
                                onChanged: (v) {
                                  update(() => setState(() {
                                    if (v == true) { ignored.add(pkg); }
                                    else { ignored.remove(pkg); }
                                  }));
                                  _save();
                                },
                              );
                            },
                          )),
                    const SizedBox(height: 10),
                    _GlassButton(label: 'Готово', icon: Icons.check_rounded,
                        primary: true,
                        onPressed: () => Navigator.pop(sheetContext)),
                  ]),
                )),
              ]),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Обзор', 'Звонки', 'Уведомления', 'Доступ'];
    const icons = [
      Icons.grid_view_rounded,
      Icons.call_outlined,
      Icons.notifications_none_rounded,
      Icons.shield_outlined,
    ];
    final current = <Widget>[_homePage(), _callPage(), _notificationPage(), _permissionsPage()][page];
    return Scaffold(
      extendBody: true,
      body: Stack(children: [
        const Positioned.fill(child: _GradientBackdrop()),
        SafeArea(bottom: false, child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(21, 17, 21, 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _aqua.withValues(alpha: .17),
                    border: Border.all(color: Colors.white.withValues(alpha: .15))),
                child: const Icon(Icons.flash_on_rounded, color: _aqua, size: 23),
              ),
              const SizedBox(width: 11),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FlashAlert', style: TextStyle(fontSize: 21,
                      fontWeight: FontWeight.w900, letterSpacing: -.5)),
                  Text('LIQUID GLASS', style: TextStyle(fontSize: 9,
                      color: _muted, letterSpacing: 2.3)),
                ],
              )),
              GestureDetector(
                onTap: () { setState(() => page = 3); _status(); },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .1),
                    border: Border.all(color: Colors.white.withValues(alpha: .18))),
                  child: Icon(Icons.tune_rounded, color: _white.withValues(alpha: .9)),
                ),
              ),
            ]),
          ),
          Expanded(child: loading
              ? const Center(child: CircularProgressIndicator(color: _aqua))
              : ListView(
                  key: ValueKey(page),
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 25),
                  children: [current, const SizedBox(height: 20),
                    Text(message, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: _muted)),
                    const SizedBox(height: 16),
                  ],
                )),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12,
                MediaQuery.paddingOf(context).bottom + 8),
            child: GlassSurface(
              blur: 20,
              opacity: .15,
              radius: 27,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(children: List.generate(4, (i) {
                final selected = page == i;
                return Expanded(child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => page = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withValues(alpha: .17) : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icons[i], size: 23, color: selected ? _aqua : _muted),
                      const SizedBox(height: 3),
                      Text(labels[i], style: TextStyle(fontSize: 10,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? _white : _muted)),
                    ]),
                  ),
                ));
              })),
            ),
          ),
        ])),
      ]),
    );
  }
}
