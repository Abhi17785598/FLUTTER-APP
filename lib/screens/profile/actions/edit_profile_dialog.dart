import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/validation/validators.dart';
import '../../../providers/auth_provider.dart';

/// Name/email edit dialog — the fallback used for individual users, who have
/// no dedicated registration screen the way builders, brokers and influencers
/// do.
///
/// Extracted verbatim from `_ProfileScreenState._showEditProfileDialog` — see
/// blueprint §1.2.4 and §6. Same validators, same `AuthProvider.updateProfile`
/// call, same snackbars.
void showEditProfileDialog(BuildContext context) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final nameController =
      TextEditingController(text: authProvider.userName);
  final emailController =
      TextEditingController(text: authProvider.userEmail);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = nameController.text.trim();
            final emailVal = emailController.text.trim();
            final nameErr = Validators.required(name);
            final emailErr =
                Validators.required(emailVal) ?? Validators.email(emailVal);
            if (nameErr != null || emailErr != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(nameErr ?? emailErr!)),
              );
              return;
            }
            authProvider.updateProfile(name, emailVal);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated successfully')),
            );
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
