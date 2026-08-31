import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_panel.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_tabs.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_toolbar.dart';

/// Estructura comun de las pantallas de lista del panel (`.fq-admin-list-page`):
/// barra de herramientas + panel con pestanas y contenido (tabla).
class AdminListScaffold extends StatelessWidget {
  const AdminListScaffold({
    super.key,
    required this.searchHint,
    required this.child,
    this.tabs,
    this.tabIndex = 0,
    this.onTab,
    this.toolbarTrailing,
    this.searchController,
    this.onSearch,
  });

  final String searchHint;
  final Widget child;
  final List<String>? tabs;
  final int tabIndex;
  final ValueChanged<int>? onTab;
  final Widget? toolbarTrailing;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AdminToolbar(
            searchHint: searchHint,
            controller: searchController,
            onChanged: onSearch,
            trailing: toolbarTrailing,
          ),
          const SizedBox(height: FqGap.md),
          FqPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (tabs != null)
                  AdminTabs(
                    tabs: tabs!,
                    index: tabIndex,
                    onChanged: onTab ?? (_) {},
                  ),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
