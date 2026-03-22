// ignore_for_file: unused_import, unused_element
part of 'main.dart';

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vpn   = Provider.of<VpnProvider>(context);
    final light = Theme.of(context).brightness == Brightness.light;
    return AuraBlobBg(connected: vpn.isConnected, isLight: light,
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
        body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
          // GlassAppBar без extendBodyBehindAppBar — Flutter добавляет отступ сам
          // Нам нужен только небольшой зазор под AppBar
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _SearchBar(vpn: vpn)),
          SliverToBoxAdapter(child: _ListHeader(vpn: vpn)),
          if (vpn.filteredConfigs.isEmpty)
            SliverToBoxAdapter(child: _EmptyState(
                onScan: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => const QrScanScreen())),
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

