import 'package:flutter/material.dart';

/// The icon key of a story template (a DB row) -> a Material icon.
/// An unknown key shows a neutral sparkle, never an error.
IconData storyIcon(String? key) => switch (key) {
  'help' => Icons.help_rounded,
  'checklist' => Icons.checklist_rounded,
  'flame' => Icons.local_fire_department_rounded,
  'warning' => Icons.warning_amber_rounded,
  'insights' => Icons.insights_rounded,
  'lightbulb' => Icons.lightbulb_rounded,
  'campaign' => Icons.campaign_rounded,
  'celebration' => Icons.celebration_rounded,
  _ => Icons.auto_awesome_rounded,
};
