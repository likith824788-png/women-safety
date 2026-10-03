import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/providers/contacts_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/pin_verification_dialog.dart';
import '../../../shared/widgets/primary_button.dart';

class TrustedContactsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final Function(int)? onNavigate;

  const TrustedContactsScreen({super.key, this.onBack, this.onNavigate});

  @override
  ConsumerState<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends ConsumerState<TrustedContactsScreen> {
  bool _showAddForm = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _relCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _relCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Mobile number are required.')),
      );
      return;
    }

    final pinValid = await PinVerificationDialog.verify(
      context: context,
      actionTitle: 'Add Trusted Contact',
    );
    if (!pinValid) return;

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final rel = _relCtrl.text.trim().isEmpty ? 'Contact' : _relCtrl.text.trim();

    ref.read(contactsProvider.notifier).addContact(name, phone, email, rel);

    _nameCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _relCtrl.clear();
    setState(() => _showAddForm = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🛡️ $name added as trusted contact'),
          backgroundColor: AppColors.safeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      drawer: widget.onNavigate != null
          ? AppDrawer(currentIndex: 5, onNavigate: widget.onNavigate!)
          : null,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: 'Open navigation sidebar',
          ),
        ),
        title: const Text('Trusted Contacts'),
        actions: [
          IconButton(
            icon: Icon(_showAddForm ? Icons.close : Icons.person_add),
            onPressed: () => setState(() {
              _showAddForm = !_showAddForm;
            }),
            tooltip: _showAddForm ? 'Cancel' : 'Add contact',
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            AppCard(
              backgroundColor: AppColors.primaryNavy,
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Trusted contacts receive SOS alerts, live location links, and companion mode notifications.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Add Contact Form ───
            if (_showAddForm) ...[
              const Text('Add New Contact (Requires PIN)', style: AppTypography.titleLarge),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  children: [
                    _field(_nameCtrl, 'Full Name', Icons.person_outline),
                    const SizedBox(height: 14),
                    _field(_phoneCtrl, 'Mobile Number', Icons.phone_outlined,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    _field(_emailCtrl, 'Email Address', Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _field(_relCtrl, 'Relation (e.g. Sister, Mom, Friend)', Icons.favorite_outline),
                    const SizedBox(height: 20),
                    PrimaryButton(label: 'Verify PIN & Save Contact', onPressed: _saveContact),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ─── Contacts List ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your Guardians', style: AppTypography.titleLarge),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${contacts.length} contacts',
                    style: const TextStyle(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_add_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 14),
                      const Text(
                        'No trusted contacts yet',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add family or friends who should\nreceive your safety alerts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Add First Contact',
                        icon: Icons.person_add,
                        onPressed: () => setState(() => _showAddForm = true),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...contacts.asMap().entries.map((entry) {
                final idx = entry.key;
                final contact = entry.value;
                return _contactCard(contact, idx + 1);
              }),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(TrustedContact contact, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryNavy,
                  child: Text(
                    contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.safeGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(contact.relationship,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
                  Text('${contact.phone} • ${contact.email.isNotEmpty ? contact.email : "No email"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
              onPressed: () async {
                final pinValid = await PinVerificationDialog.verify(
                  context: context,
                  actionTitle: 'Remove ${contact.name}',
                );
                if (pinValid) {
                  ref.read(contactsProvider.notifier).removeContact(contact.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${contact.name} removed.')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryNavy),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppColors.backgroundLight,
      ),
    );
  }
}
