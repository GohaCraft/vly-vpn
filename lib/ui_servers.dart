// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
part of 'main.dart';

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vpn   = Provider.of<VpnProvider>(context);
    final light = Theme.of(context).brightness == Brightness.light;
    return VlyBlobBg(connected: vpn.isConnected, isLight: light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          title: Text(S.t('servers_title'), style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800,
              letterSpacing: 1.5, color: _textColor(context))),
          actions: [
            _ABtn(Icons.add_circle_outline_rounded,
                () => _showAddMenu(context, vpn)),
            const SizedBox(width: 4),
          ],
        ),
        body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        cacheExtent: 500, // кэшируем 500px за экраном — плавный скролл
        slivers: [
          // GlassAppBar без extendBodyBehindAppBar — Flutter добавляет отступ сам
          // Нам нужен только небольшой зазор под AppBar
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _SearchBar(vpn: vpn)),
          SliverToBoxAdapter(child: _ListHeader(vpn: vpn)),
          if (vpn.filteredConfigs.isEmpty)
            SliverToBoxAdapter(child: _EmptyState(
                onScan: () => Navigator.push(context, PageRouteBuilder(
              pageBuilder: (_, a, __) => const QrScanScreen(),
              transitionsBuilder: (_, a, __, c) => SlideTransition(
                position: Tween(begin: const Offset(0,1), end: Offset.zero)
                    .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                child: c))),
                onAdd: () => _showAddMenu(context, vpn)))
          else
            _NodeListSliver(vpn: vpn),
          // bottom spacer: nav bar height + system nav area
          SliverToBoxAdapter(child: SizedBox(
              height: 80 + MediaQuery.of(context).padding.bottom)),
        ]),
      ),
    );
  }
}