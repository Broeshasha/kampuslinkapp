import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The colour of the post on screen in the Home feed. The glass navigation
/// bar is tinted with it, so the card colour seems to run behind the bar.
class HomeAccent extends Notifier<Color?> {
  @override
  Color? build() => null;

  void set(Color? colour) {
    if (state != colour) state = colour;
  }
}

final homeAccentProvider = NotifierProvider<HomeAccent, Color?>(HomeAccent.new);
