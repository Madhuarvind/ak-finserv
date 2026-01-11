import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageLinesScreen extends StatefulWidget {
  const ManageLinesScreen({super.key});

  @override
  State<ManageLinesScreen> createState() => _ManageLinesScreenState();
}

class _ManageLinesScreenState extends State<ManageLinesScreen> {
  final ApiService _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  List<dynamic> _lines = [];
  List<dynamic> _agents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final lines = await _apiService.getAllLines(token);
        final users = await _apiService.getUsers(token);
        
        setState(() {
          _lines = lines;
          _agents = users.where((u) => u['role'] == 'field_agent').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    }
  }

  Future<void> _createNewLine() async {
    final nameController = TextEditingController();
    final areaController = TextEditingController();

    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(AppLocalizations.of(dialogContext).translate('create_line')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(dialogContext).translate('line_name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: areaController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(dialogContext).translate('area'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(dialogContext).translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || areaController.text.isEmpty) {
                // The original patch had some unrelated code here.
                // Keeping the original logic for empty fields.
                return;
              }
              
              try {
                final token = await _storage.read(key: 'jwt_token');
                if (token != null) {
                   await _apiService.createLine({
                    'name': nameController.text,
                    'area': areaController.text,
                  }, token);
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  _fetchData();
                }
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Error creating line: $e')),
                );
              }
            },
            child: Text(AppLocalizations.of(dialogContext).translate('create')),
          ),
        ],
      ),
    );
  }

  Future<void> _assignAgent(dynamic line) async {
    int? selectedAgentId = line['agent_id'];

    return showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(AppLocalizations.of(dialogContext).translate('assign_agent')),
          content: DropdownButtonFormField<int>(
            initialValue: selectedAgentId,
            items: _agents.map<DropdownMenuItem<int>>((agent) {
              return DropdownMenuItem<int>(
                value: agent['id'],
                child: Text(agent['name']),
              );
            }).toList(),
            onChanged: (val) => setDialogState(() => selectedAgentId = val),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(dialogContext).translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedAgentId == null) {
                  return;
                }
                try {
                  final token = await _storage.read(key: 'jwt_token');
                  if (token != null) {
                    await _apiService.assignLineAgent(line['id'], selectedAgentId!, token);
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    _fetchData();
                  }
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Error assigning agent: $e')),
                  );
                }
              },
              child: Text(AppLocalizations.of(dialogContext).translate('save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLock(dynamic line) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        await _apiService.toggleLineLock(line['id'], token);
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling lock: $e')),
        );
      }
    }
  }

  Future<void> _showBulkReassignDialog() async {
    int? fromAgentId;
    int? toAgentId;

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text("Bulk Agent Swap", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Move ALL lines and customers from one agent to another.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                initialValue: fromAgentId,
                decoration: const InputDecoration(labelText: "From Agent", border: OutlineInputBorder()),
                items: _agents.map<DropdownMenuItem<int>>((a) => DropdownMenuItem<int>(value: a['id'], child: Text(a['name']))).toList(),
                onChanged: (val) => setModalState(() => fromAgentId = val),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.arrow_downward_rounded, color: Colors.blueAccent),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: toAgentId,
                decoration: const InputDecoration(labelText: "To Agent", border: OutlineInputBorder()),
                items: _agents.map<DropdownMenuItem<int>>((a) => DropdownMenuItem<int>(value: a['id'], child: Text(a['name']))).toList(),
                onChanged: (val) => setModalState(() => toAgentId = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (fromAgentId == null || toAgentId == null) return;
                if (fromAgentId == toAgentId) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Source and Target agents must be different")));
                   return;
                }

                final token = await _storage.read(key: 'jwt_token');
                if (token != null) {
                  final res = await _apiService.bulkReassignAgent(fromAgentId!, toAgentId!, token);
                  if (!mounted || !ctx.mounted) return;
                  Navigator.pop(ctx);
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Success: ${res['lines_affected']} lines & ${res['customers_affected']} customers reassigned."),
                      backgroundColor: Colors.green,
                    )
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              child: const Text("Perform Swap"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('line_management'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showBulkReassignDialog,
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.blueAccent),
            label: Text("Bulk Swap", style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.route_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).translate('no_lines_found'),
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lines.length,
                  itemBuilder: (context, index) {
                    final line = _lines[index];
                    final agentName = _agents.firstWhere(
                      (a) => a['id'] == line['agent_id'],
                      orElse: () => {'name': AppLocalizations.of(context).translate('not_assigned')},
                    )['name'];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1), 
                          child: Icon(Icons.route, color: Theme.of(context).primaryColor),
                        ),
                        title: Text(
                          line['name'],
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${line['area']} • $agentName',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            line['is_locked'] ? Icons.lock : Icons.lock_open,
                            color: line['is_locked'] ? Colors.red : Colors.green,
                          ),
                          onPressed: () => _toggleLock(line),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _assignAgent(line),
                                  icon: const Icon(Icons.person_add, size: 16),
                                  label: Text(
                                    AppLocalizations.of(context).translate('assign_agent'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade50,
                                    foregroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    minimumSize: const Size(140, 36),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/admin/line_customers', arguments: line);
                                  },
                                  icon: const Icon(Icons.people, size: 16),
                                  label: Text(
                                    AppLocalizations.of(context).translate('manage_customers'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade50,
                                    foregroundColor: Colors.orange,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    minimumSize: const Size(140, 36),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewLine,
        child: const Icon(Icons.add),
      ),
    );
  }
}
