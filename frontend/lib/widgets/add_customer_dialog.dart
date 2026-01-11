import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/localizations.dart';
import '../screens/customer_id_card_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _idProofController = TextEditingController();
  final _apiService = ApiService();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _idProofController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_nameController.text.isEmpty || _mobileController.text.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final result = await _apiService.createCustomer({
          'name': _nameController.text,
          'mobile_number': _mobileController.text,
          'area': _areaController.text,
          'address': _addressController.text,
          'id_proof_number': _idProofController.text,
        }, token);

        if (mounted) {
          if (result['msg'] == 'customer_created_successfully') {
            Navigator.pop(context, true);
            // Show the ID Card
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerIdCardScreen(
                  customer: {
                    'id': result['id'],
                    'customer_id': result['customer_id'],
                    'name': _nameController.text,
                    'mobile': _mobileController.text,
                    'area': _areaController.text,
                  },
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['msg'] ?? 'Failed to create customer')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {

        setState(() => _isLoading = false);

      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(local.translate('add_customer')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: local.translate('name'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: local.translate('mobile_number'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _areaController,
            decoration: InputDecoration(
              labelText: "${local.translate('area')} (Optional)",
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: "${local.translate('address')} (Optional)",
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _idProofController,
            decoration: InputDecoration(
              labelText: "ID Proof / Aadhar (Optional)",
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(local.translate('cancel')),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleCreate,
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(local.translate('create')),
        ),
      ],
    );
  }
}
