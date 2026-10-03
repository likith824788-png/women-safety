import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';

class ContactsNotifier extends StateNotifier<List<TrustedContact>> {
  ContactsNotifier()
      : super([
          TrustedContact(
            id: 'c1',
            name: 'Likith',
            phone: '+919100771523',
            email: 'likith824788@gmail.com',
            priority: 1,
            relationship: 'Primary Contact',
          ),
          TrustedContact(
            id: 'c2',
            name: 'Sundreshan',
            phone: '+919025174327',
            email: 'sundreshan21@gmail.com',
            priority: 2,
            relationship: 'Trusted Friend',
          ),
          TrustedContact(
            id: 'c3',
            name: 'Sai Bharath',
            phone: '+916382104870',
            email: 'saibharathchalla29@gmail.com',
            priority: 3,
            relationship: 'Trusted Friend',
          ),
          TrustedContact(
            id: 'c4',
            name: 'Priya Jegan',
            phone: '+917569228039',
            email: 'priyajegan1222@gmail.com',
            priority: 4,
            relationship: 'Trusted Friend',
          ),
        ]);

  void addContact(String name, String phone, String email, String relationship) {
    final newContact = TrustedContact(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      phone: phone,
      email: email,
      priority: state.length + 1,
      relationship: relationship,
    );
    state = [...state, newContact];
  }

  void removeContact(String id) {
    state = state.where((c) => c.id != id).toList();
    _reindexPriorities();
  }

  void reorderContacts(int oldIndex, int newIndex) {
    final items = List<TrustedContact>.from(state);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(priority: i + 1);
    }
    state = items;
  }

  void _reindexPriorities() {
    final items = List<TrustedContact>.from(state);
    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(priority: i + 1);
    }
    state = items;
  }
}

final contactsProvider =
    StateNotifierProvider<ContactsNotifier, List<TrustedContact>>((ref) {
  return ContactsNotifier();
});
