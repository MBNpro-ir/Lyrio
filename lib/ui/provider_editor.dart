import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/models.dart';

Future<void> showKeyEditor(
  BuildContext context,
  LyrioController c,
  String id,
) async {
  final input = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Personal API key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Stored encrypted on this device. Leave empty to remove the saved key.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: input,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'API key'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, input.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (value != null) await c.action('saveKey', {'id': id, 'key': value});
  // Dialog route needs one frame to release its EditableText.
  await Future<void>.delayed(const Duration(milliseconds: 350));
  input.dispose();
}

Future<void> showProviderEditor(
  BuildContext context,
  LyrioController c, {
  Json? existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => ProviderEditor(controller: c, existing: existing),
);

class ProviderEditor extends StatefulWidget {
  final LyrioController controller;
  final Json? existing;
  const ProviderEditor({super.key, required this.controller, this.existing});
  @override
  State<ProviderEditor> createState() => _ProviderEditorState();
}

class _ProviderEditorState extends State<ProviderEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _url,
      _plain,
      _synced,
      _attribution,
      _keyName,
      _key;
  late String _auth;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final p = widget.existing ?? {};
    _name = TextEditingController(text: p['name'] as String? ?? '');
    _url = TextEditingController(text: p['url'] as String? ?? '');
    _plain = TextEditingController(
      text: p['plainPath'] as String? ?? 'plainLyrics',
    );
    _synced = TextEditingController(
      text: p['syncedPath'] as String? ?? 'syncedLyrics',
    );
    _attribution = TextEditingController(
      text: p['attributionPath'] as String? ?? '',
    );
    _keyName = TextEditingController(
      text: p['keyName'] as String? ?? 'X-API-Key',
    );
    _key = TextEditingController();
    _auth = p['auth'] as String? ?? 'none';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _url,
      _plain,
      _synced,
      _attribution,
      _keyName,
      _key,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final c = widget.controller;
    final id =
        widget.existing?['id'] as String? ??
        'custom_${DateTime.now().microsecondsSinceEpoch}';
    final provider = <String, dynamic>{
      'id': id,
      'name': _name.text.trim(),
      'url': _url.text.trim(),
      'plainPath': _plain.text.trim(),
      'syncedPath': _synced.text.trim(),
      'attributionPath': _attribution.text.trim(),
      'auth': _auth,
      'keyName': _keyName.text.trim(),
    };
    if (_key.text.trim().isNotEmpty &&
        !await c.action('saveKey', {'id': id, 'key': _key.text.trim()})) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    c.set('providers', [...c.providers.where((p) => p['id'] != id), provider]);
    await c.flushSettings();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .84,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            Text(
              widget.existing == null
                  ? 'Add your lyrics API'
                  : 'Edit lyrics API',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'GET over HTTPS. Song values are URL-encoded. Read string fields from a JSON object using dot paths (for example data.lyrics or results.0.lrc).',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Provider name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _url,
              minLines: 2,
              maxLines: 4,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Endpoint URL',
                hintText:
                    'https://example.com/lyrics?title={title}&artist={artist}',
                helperText: '{title}  {artist}  {album}  {duration}  {displayTitle}  {composer}  {genre}  {year}  {trackNumber}',
              ),
              validator: (v) {
                final uri = Uri.tryParse(
                  (v ?? '').replaceAll(RegExp(r'\{[^}]+\}'), 'sample'),
                );
                if (uri == null ||
                    uri.scheme != 'https' ||
                    uri.host.isEmpty ||
                    uri.userInfo.isNotEmpty) {
                  return 'Use a valid HTTPS URL without embedded credentials';
                }
                if (uri.queryParameters.keys.any(
                  (k) => [
                    'apikey',
                    'api_key',
                    'token',
                    'access_token',
                  ].contains(k.toLowerCase()),
                )) {
                  return 'Move API credentials to the key fields below';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plain,
              decoration: const InputDecoration(
                labelText: 'Plain lyrics JSON path',
              ),
              validator: (_) =>
                  _plain.text.trim().isEmpty && _synced.text.trim().isEmpty
                  ? 'Set at least one lyrics field'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _synced,
              decoration: const InputDecoration(
                labelText: 'Synced LRC JSON path (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _attribution,
              decoration: const InputDecoration(
                labelText: 'Attribution JSON path (optional)',
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _auth,
              decoration: const InputDecoration(labelText: 'Authentication'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No key')),
                DropdownMenuItem(value: 'bearer', child: Text('Bearer token')),
                DropdownMenuItem(value: 'header', child: Text('Custom header')),
                DropdownMenuItem(
                  value: 'query',
                  child: Text('Query parameter'),
                ),
              ],
              onChanged: (v) => setState(() => _auth = v!),
            ),
            if (_auth == 'header' || _auth == 'query') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _keyName,
                decoration: const InputDecoration(
                  labelText: 'Header or parameter name',
                ),
                validator: (v) => RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v ?? '')
                    ? null
                    : 'Use letters, digits, underscore or hyphen',
              ),
            ],
            if (_auth != 'none') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  helperText: 'Leave empty to keep your existing key',
                ),
              ),
              if (widget.existing != null)
                TextButton(
                  onPressed: () => showKeyEditor(
                    context,
                    widget.controller,
                    widget.existing!['id'] as String,
                  ),
                  child: const Text('Replace or remove saved key'),
                ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_busy ? 'Saving…' : 'Save provider'),
            ),
            if (widget.existing != null)
              TextButton(
                onPressed: () async {
                  final c = widget.controller;
                  final id = widget.existing!['id'];
                  c.set(
                    'providers',
                    c.providers.where((p) => p['id'] != id).toList(),
                  );
                  if (c.choice('provider') == id) c.set('provider', 'auto');
                  await c.action('saveKey', {'id': id, 'key': ''});
                  await c.flushSettings();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Remove this provider'),
              ),
          ],
        ),
      ),
    ),
  );
}
