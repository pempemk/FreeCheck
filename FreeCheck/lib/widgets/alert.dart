import 'package:flutter/material.dart';

/// Shows feedback as a SnackBar.
class Alert {
  const Alert(this.context);

  final BuildContext context;

  void showMessage(String message) => _show(message, isError: false);

  void showError(String message) => _show(message, isError: true);

  void _show(String message, {required bool isError}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: isError ? scheme.onErrorContainer : null),
          ),
          backgroundColor: isError ? scheme.errorContainer : null,
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          closeIconColor: isError ? scheme.onErrorContainer : null,
        ),
      );
  }
}
