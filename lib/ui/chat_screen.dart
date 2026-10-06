import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_controller.dart';
import '../data/chat_engine.dart' show providerLabel;
import '../data/models.dart';
import 'settings_screen.dart';
import 'theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.controller});
  final ChatController controller;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  ChatController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
      }
    });
  }

  void _submit() {
    final text = _input.text;
    if (text.trim().isEmpty || c.sending) return;
    _input.clear();
    c.send(text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final msgs = c.current?.messages ?? const <ChatMessage>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(c.current?.title ?? 'Friday',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'New chat',
                icon: const Icon(Icons.add_comment_outlined),
                onPressed: c.sending ? null : c.newChat,
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsScreen(controller: c))),
              ),
            ],
          ),
          drawer: _HistoryDrawer(controller: c),
          body: SafeArea(
            child: Column(
              children: [
                if (!c.hasAnyKey) _KeyBanner(onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SettingsScreen(controller: c)));
                }),
                Expanded(
                  child: msgs.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          itemCount: msgs.length,
                          itemBuilder: (_, i) => _Bubble(
                            message: msgs[i],
                            isLast: i == msgs.length - 1,
                            streaming: c.sending && i == msgs.length - 1,
                            onRetry: c.retry,
                          ),
                        ),
                ),
                _Composer(
                  controller: _input,
                  sending: c.sending,
                  onSend: _submit,
                  onStop: c.stop,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 56, color: fridayAccent.withValues(alpha: 0.9)),
            const SizedBox(height: 12),
            Text('Friday', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Ask me anything.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white60)),
          ],
        ),
      );
}

class _KeyBanner extends StatelessWidget {
  const _KeyBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF3A2E12),
        child: InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.key_rounded, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Add an OpenRouter or Groq API key to start chatting.')),
              Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isLast,
    required this.streaming,
    required this.onRetry,
  });
  final ChatMessage message;
  final bool isLast;
  final bool streaming;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final maxW = MediaQuery.of(context).size.width * 0.86;
    final waiting = streaming && message.content.isEmpty;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: message.content.isEmpty
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(
                      content: Text('Copied'), duration: Duration(seconds: 1)));
              },
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? fridayUserBubble : fridaySurface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (waiting)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else if (message.content.isNotEmpty)
                Text(message.content, style: const TextStyle(fontSize: 15.5, height: 1.35)),
              if (message.error != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFFF8A80)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(message.error!,
                          style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13)),
                    ),
                  ],
                ),
                if (isLast && !streaming)
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                  ),
              ],
              if (!isUser && message.providerId != null && !waiting) ...[
                const SizedBox(height: 6),
                Text(
                  message.note ?? 'via ${providerLabel(message.providerId!)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onStop,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Message Friday',
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? onStop : onSend,
              icon: Icon(sending ? Icons.stop_rounded : Icons.arrow_upward_rounded),
              tooltip: sending ? 'Stop' : 'Send',
            ),
          ],
        ),
      );
}

class _HistoryDrawer extends StatelessWidget {
  const _HistoryDrawer({required this.controller});
  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    final list = controller.conversations.where((c) => c.messages.isNotEmpty).toList();
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Chats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No chats yet', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final conv = list[i];
                        return ListTile(
                          selected: conv == controller.current,
                          title: Text(conv.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => controller.delete(conv),
                          ),
                          onTap: () {
                            controller.select(conv);
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
