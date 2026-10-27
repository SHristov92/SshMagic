import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// A row of keys that phone keyboards lack: Esc, Tab, Ctrl, arrows, and
/// common shell symbols. Ctrl is sticky: tap it, then type a letter.
class ExtraKeysBar extends StatelessWidget {
  const ExtraKeysBar({
    super.key,
    required this.terminal,
    required this.ctrlActive,
    required this.onCtrlToggle,
    required this.onSendText,
  });

  final Terminal terminal;
  final bool ctrlActive;
  final VoidCallback onCtrlToggle;
  final ValueChanged<String> onSendText;

  @override
  Widget build(BuildContext context) {
    final keys = <Widget>[
      _KeyButton(label: 'Esc', onTap: () => terminal.keyInput(TerminalKey.escape)),
      _KeyButton(label: 'Tab', onTap: () => terminal.keyInput(TerminalKey.tab)),
      _KeyButton(label: 'Ctrl', highlighted: ctrlActive, onTap: onCtrlToggle),
      _KeyButton(label: '^C', onTap: () => onSendText('\x03')),
      _KeyButton(icon: Icons.keyboard_arrow_left, onTap: () => terminal.keyInput(TerminalKey.arrowLeft)),
      _KeyButton(icon: Icons.keyboard_arrow_up, onTap: () => terminal.keyInput(TerminalKey.arrowUp)),
      _KeyButton(icon: Icons.keyboard_arrow_down, onTap: () => terminal.keyInput(TerminalKey.arrowDown)),
      _KeyButton(icon: Icons.keyboard_arrow_right, onTap: () => terminal.keyInput(TerminalKey.arrowRight)),
      for (final s in const ['|', '/', '-', '~', r'$', '*', '&', '>'])
        _KeyButton(label: s, onTap: () => onSendText(s)),
      _KeyButton(label: 'Home', onTap: () => terminal.keyInput(TerminalKey.home)),
      _KeyButton(label: 'End', onTap: () => terminal.keyInput(TerminalKey.end)),
      _KeyButton(label: 'PgUp', onTap: () => terminal.keyInput(TerminalKey.pageUp)),
      _KeyButton(label: 'PgDn', onTap: () => terminal.keyInput(TerminalKey.pageDown)),
    ];
    return _Bar(children: keys);
  }
}

/// tmux prefix shortcuts (Ctrl-b + key) for common actions.
class TmuxKeysBar extends StatelessWidget {
  const TmuxKeysBar({super.key, required this.onSendText});

  final ValueChanged<String> onSendText;

  static const _prefix = '\x02';

  @override
  Widget build(BuildContext context) {
    Widget action(String label, String key, {IconData? icon}) => _KeyButton(
          label: label,
          icon: icon,
          onTap: () => onSendText('$_prefix$key'),
        );
    return _Bar(
      dense: true,
      children: [
        action('new', 'c', icon: Icons.add_box_outlined),
        action('prev', 'p', icon: Icons.chevron_left),
        action('next', 'n', icon: Icons.chevron_right),
        action('windows', 'w', icon: Icons.list),
        action('split |', '%'),
        action('split —', '"'),
        action('pane', 'o', icon: Icons.swap_horiz),
        action('zoom', 'z', icon: Icons.fullscreen),
        action('scroll', '[', icon: Icons.unfold_more),
        action('detach', 'd', icon: Icons.logout),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.children, this.dense = false});

  final List<Widget> children;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SizedBox(
        height: dense ? 36 : 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          children: children,
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({this.label, this.icon, required this.onTap, this.highlighted = false});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = highlighted ? scheme.onPrimary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Material(
        color: highlighted ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: icon != null && label == null
                  ? Icon(icon, size: 20, color: fg)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 4)],
                        Text(label!, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
