import 'package:flutter/material.dart';
import 'package:shoe_store_manager/models/app_user.dart';
import '../local/local_api.dart';

class UserViewScreen extends StatefulWidget {
  const UserViewScreen({super.key});

  @override
  State<UserViewScreen> createState() => _UserViewScreenState();
}

class _UserViewScreenState extends State<UserViewScreen> {
  bool loading = true;
  List<AppUser> users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      await LocalApi.I.init();
      final list = await LocalApi.I.getAllUsers(); // ✅ edhe inactive
      if (!mounted) return;
      setState(() => users = list);
    } catch (e) {
      if (!mounted) return;
      _err('$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _err(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gabim', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(msg),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fshij user?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('A je i sigurt me fshi "${u.username}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anulo')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            label: const Text('Fshij'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await LocalApi.I.deleteUser(u.id);
      await _load();
    } catch (e) {
      _err('$e');
    }
  }

  Future<void> _openEditor({AppUser? edit}) async {
    final userC = TextEditingController(text: edit?.username ?? '');
    final passC = TextEditingController();
    String role = edit?.role ?? 'worker';
    bool active = edit?.active ?? true;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(
            edit == null ? 'Shto User' : 'Ndrysho User',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userC,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passC,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: edit == null ? 'Password' : 'Password (opsional)',
                    hintText: edit == null ? null : 'Lëre bosh nëse s’do me e ndrru',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'worker', child: Text('worker')),
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                  ],
                  onChanged: (v) => setLocal(() => role = v ?? 'worker'),
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anulo')),
            FilledButton.icon(
              onPressed: () async {
                final u = userC.text.trim();
                final p = passC.text.trim();

                try {
                  if (edit == null) {
                    if (p.isEmpty) {
                      _err('Password i zbrazët.');
                      return;
                    }
                    await LocalApi.I.createUser(username: u, password: p, role: role);
                  } else {
                    await LocalApi.I.updateUser(
                      userId: edit.id,
                      username: u,
                      password: p.isEmpty ? null : p,
                      role: role,
                    );
                    await LocalApi.I.setUserActive(edit.id, active);
                  }

                  if (!mounted) return;
                  Navigator.pop(ctx);
                  await _load();
                } catch (e) {
                  _err('$e');
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Ruaje'),
            ),
          ],
        ),
      ),
    );

    userC.dispose();
    passC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'Shto user',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? const Center(child: Text('S’ka users.'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final u = users[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(u.username.isEmpty ? '?' : u.username[0].toUpperCase())),
              title: Text(u.username, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('role: ${u.role} • id: ${u.id}'),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () => _openEditor(edit: u),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: u.active ? 'Deactivate' : 'Activate',
                    onPressed: () async {
                      try {
                        await LocalApi.I.setUserActive(u.id, !u.active);
                        await _load();
                      } catch (e) {
                        _err('$e');
                      }
                    },
                    icon: Icon(u.active ? Icons.toggle_on : Icons.toggle_off),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => _confirmDelete(u),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
