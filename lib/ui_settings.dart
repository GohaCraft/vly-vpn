// ignore_for_file: unused_import, unused_element, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, prefer_final_fields, unnecessary_to_list_in_spreads, unused_local_variable, dead_code, unnecessary_null_comparison, avoid_print, unused_field, unnecessary_statements, duplicate_ignore, unnecessary_brace_in_string_interp, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unnecessary_string_escapes, library_private_types_in_public_api, non_constant_identifier_names, constant_identifier_names, use_build_context_synchronously, no_leading_underscores_for_local_identifiers, unnecessary_import, depend_on_referenced_packages, unnecessary_overrides, avoid_unnecessary_containers, sized_box_for_whitespace, sort_child_properties_last, prefer_final_locals, omit_local_variable_types, always_use_package_imports, curly_braces_in_flow_control_structures, argument_type_not_assignable, invalid_assignment, body_might_complete_normally
part of 'main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return VlyBlobBg(isLight: light, child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text(S.t('settings'), style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800,
            letterSpacing: 1.5, color: _textColor(context))),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxW),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                context.pagePadding.left.clamp(16.0, double.infinity),
                8,
                context.pagePadding.right.clamp(16.0, double.infinity),
                80 + MediaQuery.of(context).padding.bottom),
            children: [

          // ═══════════════════════════════════════════════════════════════
          // 1. ТУННЕЛЬ
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_tunnel')),
          _SettingsTile(
            icon: Icons.route_outlined,
            iconColor: const Color(0xFF26A69A),
            title: S.t('tunnel_settings'),
            subtitle: S.t('sub_tunnel'),
            helpText: S.t('help_tunnel'),
            onTap: () => _push(context, const _TunnelPage())),
          _SettingsTile(
            icon: Icons.call_split_rounded,
            iconColor: const Color(0xFFAB47BC),
            title: S.t('split_tunnel'),
            subtitle: S.t('sub_split_apps'),
            onTap: () {
              final vpn = Provider.of<VpnProvider>(context, listen: false);
              Navigator.push(context, CupertinoPageRoute(
                  builder: (_) => SplitTunnelAppsScreen(vpn: vpn)));
            }),
          _SettingsTile(
            icon: Icons.wifi_tethering_rounded,
            iconColor: const Color(0xFF42A5F5),
            title: S.t('lan_share'),
            subtitle: S.t('sub_lan'),
            helpText: S.t('help_lan'),
            onTap: () => _push(context, const _LanPage())),

          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════════════
          // 2. БЕЗОПАСНОСТЬ И ОБХОД
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_security')),
          _SettingsTile(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF43A047),
            title: S.t('protection'),
            subtitle: S.t('sub_protection'),
            onTap: () => _push(context, const _ProtectionPage())),
          _SettingsTile(
            icon: Icons.blur_on_rounded,
            iconColor: const Color(0xFF7C4DFF),
            title: S.t('stealth_engine'),
            subtitle: 'Anti-DPI · JA4+ · Reality SNI · Siberia',
            helpText: S.t('help_stealth'),
            onTap: () => _push(context, const _StealthPage())),
          _SettingsTile(
            icon: Icons.theater_comedy_outlined,
            iconColor: const Color(0xFFFF6D00),
            title: S.t('camouflage'),
            subtitle: S.t('sub_camouflage'),
            helpText: S.t('help_camouflage'),
            onTap: () => _push(context, const _CamouflagePage())),
          _SettingsTile(
            icon: Icons.psychology_outlined,
            iconColor: _accent,
            title: S.t('ai_bypass_engine'),
            subtitle: S.t('sub_ai_bypass'),
            helpText: S.t('help_ai_bypass'),
            onTap: () => _push(context, const _AiBypassPage())),
          _SettingsTile(
            icon: Icons.public_off_rounded,
            iconColor: const Color(0xFF7C4DFF),
            title: S.t('wl_bypass_title'),
            subtitle: 'CDN · WebSocket · 443',
            helpText: S.t('help_wl_bypass'),
            onTap: () => _push(context, const _BypassPage())),

          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════════════
          // 3. ПОДПИСКИ
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_subscriptions')),
          _SettingsTile(
            icon: Icons.rss_feed_rounded,
            iconColor: const Color(0xFF26A69A),
            title: S.t('subs_manage'),
            subtitle: S.t('sub_subs_manage'),
            helpText: S.t('help_subs_manage'),
            onTap: () => _push(context, const _SubscriptionsPage())),
          _SettingsTile(
            icon: Icons.update_rounded,
            iconColor: const Color(0xFF29B6F6),
            title: S.t('sub_settings'),
            subtitle: S.t('sub_sub_settings'),
            helpText: S.t('help_sub_settings'),
            onTap: () => _push(context, const _SubSettingsPage())),

          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════════════
          // 4. СОЕДИНЕНИЕ
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_connection')),
          _SettingsTile(
            icon: Icons.wifi_outlined,
            iconColor: const Color(0xFF29B6F6),
            title: S.t('auto_connect'),
            subtitle: S.t('sub_auto_connect'),
            onTap: () => _push(context, const _AutoConnectPage())),
          _SettingsTile(
            icon: Icons.speed_rounded,
            iconColor: const Color(0xFFFFCA28),
            title: S.t('ping_settings'),
            subtitle: 'TCP · Proxy · ICMP · URL',
            helpText: S.t('help_ping'),
            onTap: () => _push(context, const _PingSettingsPage())),
          _SettingsTile(
            icon: Icons.fact_check_outlined,
            iconColor: const Color(0xFF66BB6A),
            title: S.t('whitelist_test'),
            subtitle: S.t('sub_whitelist_test'),
            onTap: () => _push(context, const _WhitelistTesterPage())),

          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════════════
          // 5. ИНТЕРФЕЙС
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_interface')),
          _SettingsTile(
            icon: Icons.palette_outlined,
            iconColor: const Color(0xFFFF7043),
            title: S.t('theme_skins'),
            subtitle: S.t('sub_theme_skins'),
            helpText: S.t('help_theme_skins'),
            onTap: () => _push(context, const _AppearancePage())),
          _SettingsTile(
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF26C6DA),
            title: S.t('language'),
            subtitle: '${S.localeNames.values.take(4).join(', ')}…',
            onTap: () => _push(context, const _LanguagePage())),

          const SizedBox(height: 20),

          // ═══════════════════════════════════════════════════════════════
          // 6. ДАННЫЕ И АККАУНТ
          // ═══════════════════════════════════════════════════════════════
          _SettingsSection(title: S.t('section_data')),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            iconColor: const Color(0xFF5C6BC0),
            title: S.t('profiles'),
            subtitle: S.t('sub_profiles'),
            onTap: () => _push(context, const _ProfilesPage())),
          _SettingsTile(
            icon: Icons.backup_outlined,
            iconColor: const Color(0xFF8D6E63),
            title: S.t('backup'),
            subtitle: S.t('sub_backup'),
            onTap: () => _push(context, const _BackupPage())),
          _SettingsTile(
            icon: Icons.history_rounded,
            iconColor: const Color(0xFF78909C),
            title: S.t('history'),
            subtitle: S.t('sub_history'),
            onTap: () => _push(context, const _HistoryPage())),
          _SettingsTile(
            icon: Icons.terminal_rounded,
            iconColor: const Color(0xFF546E7A),
            title: S.t('logs'),
            subtitle: S.t('sub_logs'),
            onTap: () => _push(context, const _LogsPage())),

          const SizedBox(height: 20),

          // О приложении
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF42A5F5),
            title: S.t('about_app'),
            subtitle: 'v$gAppVersion · build $gAppBuild',
            onTap: () => _push(context, const _AboutPage())),

          const SizedBox(height: 32),
        ],
        ),  // ListView
        ),  // ConstrainedBox
      ),    // Align
    ));     // Scaffold + VlyBlobBg
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, CupertinoPageRoute(builder: (_) => page));
  }
}

// ── Tunnel Settings Page ─────────────────────────────────────────────────────

class _TunnelPage extends StatelessWidget {
  const _TunnelPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: S.t('tunnel_settings'), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [

      _SubSection(S.t('routing')),
      _SwitchRow(
        icon: Icons.route_outlined, iconColor: const Color(0xFF26A69A),
        title: S.t('smart_routing'),
        subtitle: S.t('sub_smart_routing'),
        value: true, onChanged: null,
        trailing: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18)),
      const SizedBox(height: 4),
      _SubSection(S.t('ip_preference')),
      _RadioGroup<String>(
        value: vpn.ipPreference,
        options: [
          ('auto',  S.t('ip_auto'),  S.t('ip_auto_d')),
          ('ipv4',  '4️⃣  IPv4',  S.t('ip_v4_d')),
          ('ipv6',  '6️⃣  IPv6',  S.t('ip_v6_d')),
        ],
        onChanged: vpn.setIpPreference),

      const SizedBox(height: 16),
      _SubSection(S.t('mux_enable')),
      _SwitchRow(
        icon: Icons.compress_rounded, iconColor: const Color(0xFF42A5F5),
        title: S.t('mux_on'),
        subtitle: S.t('sub_mux'),
        value: vpn.enableMux,
        onChanged: vpn.setEnableMux,
        hint: S.t('hint_mux')),
      _InfoCard(
        icon: Icons.info_outline_rounded,
        text: S.t('info_mux')),

      const SizedBox(height: 16),
      _SubSection(S.t('tun_enable')),
      _SwitchRow(
        icon: Icons.router_outlined, iconColor: const Color(0xFF7C4DFF),
        title: S.t('tun_on'),
        subtitle: S.t('sub_tun'),
        value: vpn.enableTun,
        onChanged: vpn.setEnableTun,
        hint: S.t('hint_tun')),
      if (vpn.enableTun) ...[
        const SizedBox(height: 4),
        _RadioGroup<String>(
          value: vpn.tunMode,
          options: [
            ('mixed',   S.t('tun_mixed'),  S.t('tun_mixed_d')),
            ('fakedns', 'FakeDNS',    S.t('tun_fakedns_d')),
          ],
          onChanged: vpn.setTunMode),
        const SizedBox(height: 8),
        _SwitchRow(
          icon: Icons.dns_outlined, iconColor: const Color(0xFF29B6F6),
          title: S.t('dns_for_tun'),
          subtitle: S.t('sub_dns_tun'),
          value: vpn.enableDns,
          onChanged: vpn.setEnableDns),
        if (vpn.enableDns) ...[
          const SizedBox(height: 4),
          _TextInputRow(
            label: S.t('dns_addr'),
            hint: '1.1.1.1',
            value: vpn.dnsAddress,
            onChanged: vpn.setDnsAddress),
        ],
      ],

      const SizedBox(height: 16),
      _SubSection(S.t('section_data')),
      _SwitchRow(
        icon: Icons.analytics_outlined, iconColor: const Color(0xFFFF7043),
        title: S.t('packet_analysis'),
        subtitle: S.t('sub_packet'),
        value: vpn.enablePacketSniff,
        onChanged: vpn.setPacketSniff,
        hint: S.t('hint_packet')),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.swap_horiz_rounded, iconColor: const Color(0xFF78909C),
        title: S.t('system_proxy'),
        subtitle: S.t('sub_system_proxy'),
        value: vpn.enableSystemProxy,
        onChanged: vpn.setSystemProxy),
    ]));
  }
}

// ── LAN Page ─────────────────────────────────────────────────────────────────

class _LanPage extends StatelessWidget {
  const _LanPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: S.t('lan_share'), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      _InfoCard(
        icon: Icons.wifi_tethering_rounded,
        text: S.t('info_lan')),
      const SizedBox(height: 16),
      _SubSection(S.t('access_caps')),
      _SwitchRow(
        icon: Icons.wifi_tethering_rounded, iconColor: const Color(0xFF42A5F5),
        title: S.t('allow_lan'),
        subtitle: S.t('sub_allow_lan'),
        value: vpn.enableLan,
        onChanged: vpn.setEnableLan),
      if (vpn.enableLan) ...[
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.info_outline_rounded,
          text: S.t('info_socks')),
      ],
    ]));
  }
}

// ── Sub Settings Page ────────────────────────────────────────────────────────

class _SubSettingsPage extends StatelessWidget {
  const _SubSettingsPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: S.t('update_params'), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [

      _SubSection(S.t('auto_update_caps')),
      _SwitchRow(
        icon: Icons.update_rounded, iconColor: const Color(0xFF29B6F6),
        title: S.t('title_auto_upd'),
        subtitle: S.t('sub2_auto_upd'),
        value: vpn.subAutoUpdate,
        onChanged: vpn.setSubAutoUpdate),
      if (vpn.subAutoUpdate) ...[
        const SizedBox(height: 4),
        _StepperRow(
          label: S.t('interval_hours'),
          value: vpn.subUpdateInterval,
          min: 1, max: 72, step: 1,
          onChanged: vpn.setSubInterval),
      ],

      const SizedBox(height: 16),
      _SubSection(S.t('startup_params_caps')),
      _SwitchRow(
        icon: Icons.refresh_rounded, iconColor: const Color(0xFF26A69A),
        title: S.t('upd_on_open'),
        subtitle: S.t('sub_upd_on_open'),
        value: vpn.subUpdateOnOpen,
        onChanged: vpn.setSubUpdateOnOpen),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.speed_rounded, iconColor: const Color(0xFFFFCA28),
        title: S.t('ping_on_open'),
        subtitle: S.t('sub_ping_on_open'),
        value: vpn.subPingOnOpen,
        onChanged: vpn.setSubPingOnOpen),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.play_arrow_rounded, iconColor: const Color(0xFF66BB6A),
        title: S.t('connect_on_open'),
        subtitle: S.t('sub_connect_on_open'),
        value: vpn.subConnectOnOpen,
        onChanged: vpn.setSubConnectOnOpen),

      const SizedBox(height: 16),
      _SubSection(S.t('logic_caps')),
      _SwitchRow(
        icon: Icons.filter_list_off_rounded, iconColor: const Color(0xFF78909C),
        title: S.t('allow_dups'),
        subtitle: S.t('allow_dups_desc'),
        value: vpn.subAllowDups,
        onChanged: vpn.setSubAllowDups),

      const SizedBox(height: 16),
      _SubSection(S.t('sorting_caps')),
      _RadioGroup<String>(
        value: vpn.subSortMode,
        options: [
          ('none',  S.t('sort_none'), S.t('sort_none_d')),
          ('ping',  S.t('sort_ping'),       S.t('sort_ping_d')),
          ('alpha', S.t('sort_alpha'),    S.t('sort_alpha_d')),
        ],
        onChanged: vpn.setSubSortMode),

      const SizedBox(height: 16),
      _SubSection('USER AGENT'),
      _TextInputRow(
        label: S.t('ua_requests'),
        hint: 'Vly/$gAppVersion/Android',
        value: vpn.subUserAgent,
        onChanged: vpn.setSubUserAgent),
    ]));
  }
}

// ── Ping Settings Page ───────────────────────────────────────────────────────

class _PingSettingsPage extends StatelessWidget {
  const _PingSettingsPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: S.t('ping_settings'), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [

      _SubSection(S.t('ping_type_caps')),
      _RadioGroup<String>(
        value: vpn.pingType,
        options: [
          ('tcp',   'TCP',        S.t('ping_tcp_d')),
          ('proxy', 'via Proxy',  S.t('ping_proxy_d')),
          ('icmp',  'ICMP',       S.t('ping_icmp_d')),
        ],
        onChanged: vpn.setPingType),

      const SizedBox(height: 16),
      _SubSection(S.t('test_url_caps')),
      _TextInputRow(
        label: S.t('url_to_check'),
        hint: 'https://www.gstatic.com/generate_204',
        value: vpn.pingUrl,
        onChanged: vpn.setPingUrl),
      _InfoCard(
        icon: Icons.info_outline_rounded,
        text: S.t('info_ping_url')),

      const SizedBox(height: 16),
      _SubSection(S.t('result_caps')),
      _DetailRow2('📊', S.t('res_display'), S.t('res_display_d')),
      _DetailRow2('🔄', S.t('res_repeats'), S.t('res_repeats_d')),
      _DetailRow2('⏱', S.t('res_timeout'), S.t('res_timeout_d')),
    ]));
  }
}

// ── Helpers: RadioGroup, StepperRow, TextInputRow ────────────────────────────

class _RadioGroup<T> extends StatelessWidget {
  final T value;
  final List<(T, String, String)> options; // (value, label, subtitle)
  final ValueChanged<T> onChanged;
  const _RadioGroup({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(children: options.map((opt) {
      final sel = value == opt.$1;
      return GestureDetector(
        onTap: () => onChanged(opt.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: sel ? _accent.withOpacity(0.12) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? _accent.withOpacity(0.5) : Colors.white.withOpacity(0.08))),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: sel ? _accent : Colors.white30, width: sel ? 5 : 1.5)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(opt.$2, style: TextStyle(
                  fontSize: 13, color: sel ? _accent : Colors.white70,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
              Text(opt.$3, style: const TextStyle(fontSize: 10, color: Colors.white38)),
            ])),
          ]),
        ),
      );
    }).toList());
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;
  const _StepperRow({required this.label, required this.value,
      required this.min, required this.max, required this.step,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.white70))),
        GestureDetector(
          onTap: value > min ? () => onChanged(value - step) : null,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(value > min ? 0.08 : 0.02),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.remove, size: 16,
                color: value > min ? Colors.white70 : Colors.white24))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('$value',
              style: TextStyle(fontSize: 16, color: _accent, fontWeight: FontWeight.bold))),
        GestureDetector(
          onTap: value < max ? () => onChanged(value + step) : null,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(value < max ? 0.08 : 0.02),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.add, size: 16,
                color: value < max ? Colors.white70 : Colors.white24))),
      ]),
    );
  }
}

class _TextInputRow extends StatefulWidget {
  final String label, hint, value;
  final ValueChanged<String> onChanged;
  const _TextInputRow({required this.label, required this.hint,
      required this.value, required this.onChanged});
  @override State<_TextInputRow> createState() => _TextInputRowState();
}

class _TextInputRowState extends State<_TextInputRow> {
  late final TextEditingController _ctrl;
  @override void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
        TextField(
          controller: _ctrl,
          style: TextStyle(fontSize: 13, color: _accent),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.white24),
            border: InputBorder.none, isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6)),
          onChanged: widget.onChanged,
          onSubmitted: widget.onChanged,
        ),
      ]),
    );
  }
}


// ── Camouflage Page ──────────────────────────────────────────────────────────

class _CamouflagePage extends StatelessWidget {
  const _CamouflagePage();

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);

    return _SubPage(
      title: S.t('camouflage_traffic'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        _InfoCard(
          icon: Icons.theater_comedy_outlined,
          text: S.t('info_camo')),
        const SizedBox(height: 16),

        _SubSection(S.t('choose_camo_caps')),
        ...CamouflageMode.values.map((mode) {
          final selected = vpn.camouflageMode == mode.name;
          return GestureDetector(
            onTap: () => vpn.setCamouflageMode(mode.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? _accent.withOpacity(0.12)
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: selected
                        ? _accent.withOpacity(0.6)
                        : Colors.white.withOpacity(0.08),
                    width: selected ? 1.5 : 1.0),
                boxShadow: selected
                    ? [BoxShadow(color: _accent.withOpacity(0.15), blurRadius: 16)]
                    : [],
              ),
              child: Row(children: [
                // Иконка сервиса
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? _accent.withOpacity(0.20)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Icon(mode.icon, size: 22,
                      color: selected ? _accent : Colors.white70))),
                const SizedBox(width: 14),
                // Текст
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(mode.label, style: TextStyle(
                          fontSize: 14,
                          color: selected ? _accent : Colors.white.withOpacity(0.85),
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                      if (mode == CamouflageMode.none)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4)),
                          child: Text(S.t('default_caps'),
                              style: TextStyle(fontSize: 8, color: Colors.green,
                                  fontWeight: FontWeight.bold))),
                      if (mode == CamouflageMode.microsoft || mode == CamouflageMode.apple)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4)),
                          child: Text(S.t('strong_caps'),
                              style: TextStyle(fontSize: 8, color: Colors.orange,
                                  fontWeight: FontWeight.bold))),
                      if (mode == CamouflageMode.naive)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C4DFF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4)),
                          child: Text(S.t('top_caps'),
                              style: TextStyle(fontSize: 8, color: Color(0xFF7C4DFF),
                                  fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 3),
                    Text(mode.description,
                        style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                )),
                // Индикатор выбора
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? _accent : Colors.white24,
                        width: selected ? 6 : 1.5)),
                ),
              ]),
            ),
          );
        }).toList(),

        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.warning_amber_rounded,
          text: S.t('info_camo_warn')),
      ]),
    );
  }
}


// ── Help Tooltip ─────────────────────────────────────────────────────────────
// Маленькая кнопка ? — при нажатии показывает снекбар-объяснение снизу

class _HelpBtn extends StatelessWidget {
  final String text;
  const _HelpBtn(this.text);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _showHelp(context),
    child: Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.18))),
      child: const Center(
        child: Text('?', style: TextStyle(
            fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)))),
  );

  void _showHelp(BuildContext context) {
    final overlay = Overlay.of(context);
    final entry   = OverlayEntry(builder: (_) => _HelpOverlay(text: text));
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), entry.remove);
  }
}

class _HelpOverlay extends StatefulWidget {
  final String text;
  const _HelpOverlay({required this.text});
  @override State<_HelpOverlay> createState() => _HelpOverlayState();
}

class _HelpOverlayState extends State<_HelpOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>    _fade;

  @override
  void initState() {
    super.initState();
    _c    = AnimationController(duration: const Duration(milliseconds: 220), vsync: this);
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _c.forward();
    // Начинаем fade-out за 400ms до удаления
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (mounted) _c.reverse();
    });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 80,
      left: 16, right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F35).withOpacity(0.97),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4),
                  blurRadius: 20, spreadRadius: 2)]),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 16, color: _accent.withOpacity(0.8)),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.text, style: const TextStyle(
                  fontSize: 13, color: Colors.white, height: 1.4))),
            ]),
          ),
        ),
      ),
    );
  }
}


// ── Settings Tile ─────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  const _SettingsSection({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
    child: Text(title, style: TextStyle(
        fontSize: 10, letterSpacing: 2,
        color: _subTextColor(context).withOpacity(0.45),
        fontWeight: FontWeight.w600)));
}

class _SettingsTile extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool isPage;
  final String? helpText; // подсказка при нажатии ?

  const _SettingsTile({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    this.onTap, this.isPage = true, this.helpText,
  });

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: light ? Colors.white.withOpacity(0.75) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: light ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.07)),
          boxShadow: light ? [BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8,
              offset: const Offset(0, 2))] : [],
        ),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconColor.withOpacity(0.25))),
            child: Icon(icon, size: 18, color: iconColor)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(title, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: _textColor(context)))),
              if (helpText != null) ...[
                const SizedBox(width: 6),
                _HelpBtn(helpText!),
              ],
            ]),
            Text(subtitle, style: TextStyle(
                fontSize: 10, color: _subTextColor(context).withOpacity(0.55))),
          ])),
          if (isPage) Icon(Icons.chevron_right_rounded, size: 18,
              color: _subTextColor(context).withOpacity(0.35)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SETTINGS SUBPAGES
// ═══════════════════════════════════════════════════════════════════════════════

// ── Profiles Page ─────────────────────────────────────────────────────────────

class _ProfilesPage extends StatelessWidget {
  const _ProfilesPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: S.t('profiles'), child: Column(children: [
      ...vpn.profiles.asMap().entries.map((e) {
        final prof = e.value;
        final isActive = prof.id == vpn.activeProfileId;
        return GestureDetector(
          onTap: () { vpn.switchProfile(prof.id); },
          child: Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isActive ? _accent.withOpacity(0.10) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? _accent.withOpacity(0.4) : Colors.white.withOpacity(0.08))),
            child: Row(children: [
              AnimatedContainer(duration: const Duration(milliseconds: 200),
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? _accent : Colors.white24,
                  boxShadow: isActive ? [BoxShadow(
                      color: _accent.withOpacity(0.6), blurRadius: 6)] : [])),
              const SizedBox(width: 12),
              Expanded(child: Text(prof.name, style: TextStyle(
                  fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive ? _textColor(context) : _subTextColor(context)))),
              if (isActive) Text(S.t('profile_active'), style: TextStyle(
                  fontSize: 9, color: _accent, fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
              if (!isActive && vpn.profiles.length > 1) GestureDetector(
                onTap: () => vpn.deleteProfile(prof.id),
                child: Padding(padding: const EdgeInsets.only(left: 12),
                  child: Icon(Icons.delete_outline_rounded, size: 16,
                      color: Colors.redAccent.withOpacity(0.6)))),
            ])));
      }),
      const SizedBox(height: 12),
      _ActionBtn(
        icon: Icons.add_rounded, label: S.t('profile_new'),
        color: _accent,
        onTap: () => _dlgNewProfile(context, vpn)),
    ]));
  }

  void _dlgNewProfile(BuildContext ctx, VpnProvider vpn) {
    final c = TextEditingController();
    showCupertinoDialog(context: ctx, builder: (x) => CupertinoAlertDialog(
      title: Text(S.t('profile_new')),
      content: Padding(padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(controller: c,
              placeholder: S.t('profile_name'), autofocus: true)),
      actions: [
        CupertinoDialogAction(isDestructiveAction: true,
            onPressed: () => Navigator.pop(x), child: Text(S.t('cancel'))),
        CupertinoDialogAction(
            onPressed: () { vpn.createProfile(c.text); Navigator.pop(x); },
            child: Text(S.t('save'))),
      ],
    ));
  }
}

// ── Subscriptions Page ────────────────────────────────────────────────────────

class _SubscriptionsPage extends StatefulWidget {
  const _SubscriptionsPage();
  @override State<_SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<_SubscriptionsPage> {
  final _ctrl = TextEditingController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    final subs = vpn.subLinks;
    return _SubPage(title: S.t('subscriptions'), child: Column(children: [
      // Список подписок
      if (subs.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(S.t('no_subscriptions'), style: const TextStyle(
              fontSize: 13, color: Colors.white38)))
      else
        ...subs.map((url) {
          final name = vpn.groupNameFromUrl(url);
          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: Row(children: [
              const Icon(Icons.rss_feed_rounded, size: 16, color: Colors.white30),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(name, style: const TextStyle(
                    fontSize: 12, color: Colors.white70,
                    fontWeight: FontWeight.w500)),
                Text(url, style: const TextStyle(
                    fontSize: 9, color: Colors.white24),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              GestureDetector(
                onTap: () async { await vpn.refreshSubscription(url); },
                child: const Icon(Icons.refresh_rounded,
                    size: 16, color: Colors.white38)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => vpn.removeSubscription(vpn.subLinks.indexOf(url)),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Colors.redAccent)),
            ]));
        }),
      const SizedBox(height: 16),
      // Поле добавить
      ClipRRect(borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            decoration: InputDecoration(
              hintText: 'https://your-sub-url…',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.white24),
              filled: true, fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12)),
          ))),
      const SizedBox(height: 10),
      _ActionBtn(
        icon: Icons.add_rounded, label: S.t('add_subscription'),
        color: const Color(0xFF26A69A),
        onTap: () async {
          final url = _ctrl.text.trim();
          if (url.isEmpty) return;
          await vpn.addSubscription(url);
          _ctrl.clear();
        }),
    ]));
  }
}

// ── Backup Page ───────────────────────────────────────────────────────────────

class _BackupPage extends StatefulWidget {
  const _BackupPage();
  @override State<_BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<_BackupPage> {
  final _pwCtrl = TextEditingController();
  final _imCtrl = TextEditingController();
  @override void dispose() { _pwCtrl.dispose(); _imCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: S.t('backup'), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SubSection(S.t('export_caps')),
      ClipRRect(borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: TextField(controller: _pwCtrl,
            obscureText: true,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            decoration: InputDecoration(
              hintText: S.t('backup_password_hint'),
              hintStyle: const TextStyle(fontSize: 12, color: Colors.white24),
              prefixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.white24),
              filled: true, fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12)),
          ))),
      const SizedBox(height: 10),
      _ActionBtn(
        icon: Icons.upload_outlined, label: S.t('backup_export'),
        color: const Color(0xFF8D6E63),
        onTap: () async {
          final data = vpn.exportBackup(_pwCtrl.text.trim());
          await Clipboard.setData(ClipboardData(text: data));
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.t('backup_copied')),
            backgroundColor: const Color(0xFF1B2A1B)));
        }),
      const SizedBox(height: 24),
      _SubSection(S.t('import_caps')),
      ClipRRect(borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: TextField(controller: _imCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 11,
                fontFamily: 'monospace', color: Colors.white70),
            decoration: InputDecoration(
              hintText: S.t('backup_import_hint'),
              hintStyle: const TextStyle(fontSize: 11, color: Colors.white24),
              filled: true, fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(14)),
          ))),
      const SizedBox(height: 10),
      _ActionBtn(
        icon: Icons.download_outlined, label: S.t('backup_import'),
        color: const Color(0xFF5C6BC0),
        onTap: () async {
          final ok = await vpn.importBackup(
              _imCtrl.text.trim(), _pwCtrl.text.trim());
          _imCtrl.clear();
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? S.t('restore_ok') : S.t('restore_fail')),
            backgroundColor: ok
                ? const Color(0xFF1B2A1B) : const Color(0xFF2A1B1B)));
        }),
    ]));
  }
}

// ── Protection Page ───────────────────────────────────────────────────────────

class _ProtectionPage extends StatelessWidget {
  const _ProtectionPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: S.t('protection'), child: Column(children: [
      _SwitchRow(
        icon: Icons.shield_outlined, iconColor: const Color(0xFF43A047),
        title: S.t('kill_switch'), subtitle: S.t('kill_switch_sub'),
        value: vpn.killSwitch,
        onChanged: vpn.setKillSwitch),
      const SizedBox(height: 8),
      // Честно: наш переключатель делает мгновенный авто-реконнект, но полностью
      // заблокировать трафик в момент обрыва может только сама ОС (Always-on VPN
      // + Lockdown). Ведём пользователя туда одной кнопкой.
      _InfoCard(icon: Icons.info_outline, text: S.t('kill_switch_note')),
      const SizedBox(height: 8),
      _ActionRow(
        icon: Icons.verified_user_outlined, iconColor: const Color(0xFF43A047),
        title: S.t('always_on_vpn'), subtitle: S.t('always_on_vpn_sub'),
        actionLabel: S.t('open'),
        onTap: () async {
          final ok = await vpn.openSystemVpnSettings();
          if (context.mounted && !ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(S.t('always_on_vpn_hint'))));
          }
        }),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.autorenew_rounded, iconColor: const Color(0xFF29B6F6),
        title: S.t('auto_rotate'),
        subtitle: S.t('auto_rotate_sub').replaceAll('{n}', '${VpnProvider.maxFails}'),
        value: true, onChanged: null,
        trailing: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18)),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.public_off_rounded, iconColor: const Color(0xFF7C4DFF),
        title: S.t('bypass_button'),
        subtitle: vpn.bypassBtnMode
            ? S.t('bypass_btn_wl')
            : S.t('bypass_btn_vpn'),
        value: vpn.bypassBtnMode,
        onChanged: (_) => vpn.toggleBypassBtnMode()),
    ]));
  }
}

// ── AI Bypass Page ────────────────────────────────────────────────────────────

class _AiBypassPage extends StatelessWidget {
  const _AiBypassPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: 'AI Bypass + Stealth', child: Column(children: [

      // ── МЕТОД ОБХОДА ────────────────────────────────────────────────────
      _SubSection(S.t('bypass_method_caps')),
      _InfoCard(
        icon: Icons.security_outlined,
        text: S.t('info_bypass_method')),
      const SizedBox(height: 12),

      // Карточки режимов обхода
      // Показываем только режимы, которые реально запускает текущее ядро
      // (Hysteria2/ShadowTLS скрыты — xray-core их не поддерживает).
      ...BypassMode.values.where((m) => m.isAvailable).map((mode) => _BypassModeCard(
        mode: mode,
        selected: vpn.bypassMode == mode,
        onSelect: () => vpn.setBypassMode(mode),
      )),

      const SizedBox(height: 20),
      _SubSection('AI BYPASS ENGINE'),
      _SwitchRow(
        icon: Icons.psychology_outlined, iconColor: _accent,
        title: S.t('ai_bypass'), subtitle: S.t('ai_bypass_sub'),
        value: vpn.aiEnabled, onChanged: vpn.setAiEnabled),
      const SizedBox(height: 4),
      _ActionRow(
        icon: Icons.cloud_sync_outlined, iconColor: const Color(0xFF29B6F6),
        title: S.t('sync_rules'), subtitle: S.t('sync_rules_sub'),
        actionLabel: 'SYNC',
        onTap: vpn.syncRules),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.insights_outlined, iconColor: const Color(0xFF66BB6A),
        title: S.t('telemetry'), subtitle: S.t('telemetry_sub'),
        value: vpn.telemetryEnabled, onChanged: vpn.setTelemetryEnabled),

      const SizedBox(height: 20),
      _SubSection('STEALTH ENGINE 3.0'),

      // Инфо-карточка
      _InfoCard(
        icon: Icons.visibility_off_outlined,
        text: S.t('info_stealth3')),
      const SizedBox(height: 12),

      _SwitchRow(
        icon: Icons.visibility_off_outlined,
        iconColor: const Color(0xFF7C4DFF),
        title: 'Stealth Mode',
        subtitle: S.t('stealth_mode_sub'),
        value: vpn.stealthMode,
        onChanged: (v) { vpn.stealthMode = v; vpn.saveToDisk(); vpn.refresh(); }),
      const SizedBox(height: 4),

      _SwitchRow(
        icon: Icons.call_split_rounded,
        iconColor: const Color(0xFFFF6D00),
        title: S.t('tls_frag'),
        subtitle: S.t('tls_frag_sub'),
        value: vpn.stealthFragment,
        onChanged: vpn.stealthMode
            ? (v) { vpn.stealthFragment = v; vpn.saveToDisk(); vpn.refresh(); }
            : null),
      const SizedBox(height: 4),

      _SwitchRow(
        icon: Icons.language_rounded,
        iconColor: const Color(0xFF26A69A),
        title: S.t('reality_sni_rot'),
        subtitle: S.t('reality_sni_rot_sub'),
        value: vpn.stealthRealitySni,
        onChanged: vpn.stealthMode
            ? (v) { vpn.stealthRealitySni = v; vpn.saveToDisk(); vpn.refresh(); }
            : null),
      const SizedBox(height: 4),

      _SwitchRow(
        icon: Icons.local_fire_department_outlined,
        iconColor: const Color(0xFFFF5252),
        title: 'Warm-up',
        subtitle: S.t('warmup_sub'),
        value: vpn.stealthWarmup,
        onChanged: vpn.stealthMode
            ? (v) { vpn.stealthWarmup = v; vpn.saveToDisk(); vpn.refresh(); }
            : null),
      const SizedBox(height: 4),

      _SwitchRow(
        icon: Icons.apps_rounded,
        iconColor: const Color(0xFF42A5F5),
        title: S.t('per_service_bypass'),
        subtitle: S.t('per_service_bypass_sub'),
        value: vpn.perAppBypass,
        onChanged: (v) => vpn.setPerAppBypass(v)),

      const SizedBox(height: 16),
      _SubSection(S.t('current_sni_pool_caps')),
      ...kRealitySniPool.map((sni) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          const Icon(Icons.check_circle_outline, size: 12, color: Colors.white24),
          const SizedBox(width: 8),
          Text(sni, style: const TextStyle(
              fontSize: 11, fontFamily: 'monospace', color: Colors.white54)),
        ]),
      )),

      const SizedBox(height: 16),
      _SubSection('SELF-HEALING'),
      _InfoCard(
        icon: Icons.health_and_safety_outlined,
        text: S.t('info_selfheal')),
    ]));
  }
}

// ── Stealth Engine Page ──────────────────────────────────────────────────────

class _StealthPage extends StatelessWidget {
  const _StealthPage();

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: 'Stealth Engine 3.0', child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Статус
      _StealthStatusCard(vpn: vpn),
      const SizedBox(height: 16),

      _SubSection(S.t('anti_dpi_caps')),
      _SwitchRow(
        icon: Icons.broken_image_outlined, iconColor: const Color(0xFF7C4DFF),
        title: S.t('stealth_mode_title'),
        subtitle: S.t('stealth_mode_sub2'),
        value: vpn.stealthMode,
        onChanged: (v) => vpn.setStealthMode(v),
        hint: S.t('hint_stealth_master')),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.scatter_plot_outlined, iconColor: const Color(0xFF7C4DFF),
        title: S.t('tls_frag'),
        subtitle: S.t('tls_frag_sub2'),
        value: vpn.stealthFragment,
        onChanged: (v) => vpn.setStealthFragment(v),
        hint: S.t('hint_tls_frag')),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.rotate_90_degrees_cw_outlined, iconColor: const Color(0xFF7C4DFF),
        title: S.t('reality_sni_rot'),
        subtitle: 'dl.google.com · icloud.com · microsoft.com',
        value: vpn.stealthRealitySni,
        onChanged: (v) => vpn.setStealthRealitySni(v),
        hint: S.t('hint_reality_sni')),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.local_fire_department_outlined, iconColor: const Color(0xFFFF7043),
        title: S.t('warmup_title'),
        subtitle: S.t('warmup_sub2'),
        value: vpn.stealthWarmup,
        onChanged: (v) => vpn.setStealthWarmup(v),
        hint: S.t('hint_warmup')),

      const SizedBox(height: 16),
      _SubSection(S.t('siberia_block_caps')),
      _InfoCard(
        icon: Icons.shield_outlined,
        text: S.t('info_siberia')),
      const SizedBox(height: 8),
      _SwitchRow(
        icon: Icons.shield_moon_outlined, iconColor: const Color(0xFF00BCD4),
        title: 'Siberia Shield 🇷🇺',
        subtitle: 'Connection pacing · Single-tunnel XMUX · Decoy traffic',
        value: vpn.siberiaShield,
        onChanged: (v) => vpn.setSiberiaShield(v),
        hint: S.t('hint_siberia')),

      const SizedBox(height: 8),
      _SwitchRow(
        icon: Icons.apps_rounded, iconColor: const Color(0xFF7C4DFF),
        title: S.t('per_app_bypass'),
        subtitle: 'Telegram · YouTube · TikTok · Instagram · Discord · X',
        value: vpn.perAppBypass,
        onChanged: (v) => vpn.setPerAppBypass(v),
        hint: S.t('hint_per_app')),

      const SizedBox(height: 16),
      _SubSection(S.t('sni_pool_caps')),
      ...kRealitySniPool.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Row(children: [
            Text('${e.key + 1}.', style: const TextStyle(
                fontSize: 10, color: Colors.white24, fontFamily: 'monospace')),
            const SizedBox(width: 10),
            Text(e.value, style: const TextStyle(
                fontSize: 12, color: Colors.white54, fontFamily: 'monospace')),
            const Spacer(),
            if (StealthEngine.sniIndex % kRealitySniPool.length == e.key)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4)),
                child: const Text('current', style: TextStyle(
                    fontSize: 8, color: Color(0xFF7C4DFF)))),
          ])))),

      const SizedBox(height: 16),
      _SubSection(S.t('dead_drop_caps')),
      _InfoCard(
        icon: Icons.cloud_off_outlined,
        text: S.t('info_deaddrop')),
      const SizedBox(height: 8),
      ...kDeadDropMirrors.map((m) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Text(m, style: const TextStyle(
              fontSize: 10, color: Colors.white38, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)))),
    ]));
  }
}

// ── Stealth Status Card ────────────────────────────────────────────────────────

class _StealthStatusCard extends StatelessWidget {
  final VpnProvider vpn;
  const _StealthStatusCard({required this.vpn});

  @override
  Widget build(BuildContext context) {
    final active = vpn.stealthMode;
    final color  = active ? const Color(0xFF7C4DFF) : Colors.white24;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            active ? const Color(0xFF7C4DFF).withOpacity(0.15) : Colors.white.withOpacity(0.04),
            active ? const Color(0xFF4A148C).withOpacity(0.08) : Colors.white.withOpacity(0.02),
          ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(active ? 0.4 : 0.12)),
        boxShadow: active ? [
          BoxShadow(color: const Color(0xFF7C4DFF).withOpacity(0.2), blurRadius: 20)
        ] : [],
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: active ? [BoxShadow(
                color: color.withOpacity(0.3), blurRadius: 12)] : []),
          child: active
            ? Padding(padding: const EdgeInsets.all(5),
                child: Image.asset('assets/images/vly_icon.png', width: 130, height: 130, fit: BoxFit.contain))
            : Icon(Icons.security_outlined, size: 20, color: color)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(active ? S.t('stealth_active') : S.t('stealth_off'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                  color: color, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(active
              ? 'JA4+ bypass · TLS fragment · Reality SNI'
              : S.t('stealth_tap_hint'),
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.6))),
        ])),
        if (active && vpn.stealthHandshakeFails > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Text('${vpn.stealthHandshakeFails} RST',
                style: const TextStyle(fontSize: 9, color: Colors.orange))),
      ]),
    );
  }
}

// ── Bypass Page ───────────────────────────────────────────────────────────────

class _BypassPage extends StatelessWidget {
  const _BypassPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(title: S.t('wl_bypass_title'), child: Column(children: [
      _InfoCard(
        icon: Icons.info_outline_rounded,
        text: S.t('info_wl_bypass_short')),
      const SizedBox(height: 12),
      _DetailRow2('🔒', 'Порт', '443 (HTTPS)'),
      _DetailRow2('🌐', S.t('transport'), S.t('wl_transport_val')),
      _DetailRow2('🎭', 'SNI', 'speed.cloudflare.com'),
      _DetailRow2('📡', 'DNS', 'DoH — 1.1.1.1'),
      const SizedBox(height: 16),
      _ActionBtn(
        icon: vpn.whitelistBypassActive
            ? Icons.close_rounded : Icons.public_off_rounded,
        label: vpn.whitelistBypassActive
            ? S.t('deactivate') : S.t('activate_bypass'),
        color: vpn.whitelistBypassActive
            ? Colors.redAccent : const Color(0xFF7C4DFF),
        onTap: vpn.activateWhitelistBypass),
    ]));
  }
}

// ── Auto Connect Page ─────────────────────────────────────────────────────────

class _AutoConnectPage extends StatelessWidget {
  const _AutoConnectPage();
  @override
  Widget build(BuildContext context) {
    return _SubPage(title: S.t('auto_connect'), child: Column(children: [
      _SwitchRow(
        icon: Icons.wifi_outlined, iconColor: const Color(0xFF29B6F6),
        title: S.t('open_wifi'),
        subtitle: S.t('sub_open_wifi'),
        value: _autoConnect.onOpenWifi,
        onChanged: _autoConnect.toggleWifi),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.wifi_lock_outlined, iconColor: const Color(0xFF66BB6A),
        title: S.t('any_new_wifi'),
        subtitle: S.t('sub_any_new_wifi'),
        value: _autoConnect.onNewWifi,
        onChanged: _autoConnect.toggleNewWifi),
      const SizedBox(height: 4),
      _SwitchRow(
        icon: Icons.signal_cellular_alt_rounded, iconColor: const Color(0xFFFFA726),
        title: S.t('mobile_data'),
        subtitle: S.t('sub_mobile_data'),
        value: _autoConnect.onMobileData,
        onChanged: _autoConnect.toggleMobile),
      const SizedBox(height: 16),
      _ActionBtn(
        icon: Icons.apps_rounded, label: S.t('select_trigger_apps'),
        color: const Color(0xFF29B6F6),
        onTap: () => Navigator.push(context, CupertinoPageRoute(
            builder: (_) => const AutoConnectAppsScreen()))),
    ]));
  }
}

// ── Appearance Page ───────────────────────────────────────────────────────────

class _AppearancePage extends StatelessWidget {
  const _AppearancePage();
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    final light = Theme.of(context).brightness == Brightness.light;
    return _SubPage(title: S.t('theme_skins'), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SubSection(S.t('theme_caps')),
      Container(
        decoration: BoxDecoration(
          color: light ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.10))),
        child: Row(children: VlyTheme.values.map((t) {
          final sel = app.theme == t;
          final label = t == VlyTheme.dark ? S.t('theme_dark')
              : t == VlyTheme.light ? S.t('theme_light') : S.t('theme_system');
          return Expanded(child: GestureDetector(
            onTap: () => app.setTheme(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.all(3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? _accent.withOpacity(0.20) : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: sel ? Border.all(color: _accent.withOpacity(0.5)) : null),
              child: Text(label, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11,
                  color: sel ? _accent : _subTextColor(context).withOpacity(0.6),
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)))));
        }).toList())),
      const SizedBox(height: 20),
      _SubSection(S.t('skin_caps')),
      _SkinPicker(app: app),
    ]));
  }
}

// ── Language Page ─────────────────────────────────────────────────────────────

class _LanguagePage extends StatelessWidget {
  const _LanguagePage();
  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    // mainAxisExtent фиксирует ВЫСОТУ ячейки (64px) независимо от ширины экрана.
    // Раньше был childAspectRatio: 3.1 — высота зависела от ширины, и на телефоне
    // ячейка выходила ~55px при контенте ~58px → «Bottom overflowed» на КАЖДОМ
    // языке (и хуже на узких экранах). Теперь высоты хватает всегда.
    return _SubPage(title: S.t('language'), child: GridView(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 64,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: VlyLocale.values.map((loc) {
        final sel = app.locale == loc;
        return GestureDetector(
          onTap: () => app.setLocale(loc),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? _accent.withOpacity(0.14) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sel ? _accent : Colors.white.withOpacity(0.08),
                width: sel ? 1.6 : 1)),
            child: Row(children: [
              Container(width: 38, height: 38, alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06)),
                child: Text(S.localeFlags[loc] ?? '🏳️',
                  style: const TextStyle(fontSize: 21))),
              const SizedBox(width: 11),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(S.localeNames[loc] ?? loc.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5,
                      color: sel ? _accent : Colors.white,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(S.localeEnglish[loc] ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5,
                      color: Colors.white.withOpacity(0.4))),
                ])),
              if (sel) Icon(Icons.check_circle_rounded, color: _accent, size: 19),
            ])));
      }).toList()));
  }
}

// ── History Page ──────────────────────────────────────────────────────────────

class _HistoryPage extends StatelessWidget {
  const _HistoryPage();
  @override
  Widget build(BuildContext context) {
    final vpn   = Provider.of<VpnProvider>(context);
    final light = Theme.of(context).brightness == Brightness.light;
    return _SubPage(
      title: S.t('connection_history'),
      trailing: vpn.connectionHistory.isNotEmpty
          ? GestureDetector(
              onTap: vpn.clearHistory,
              child: Text(S.t('clear'), style: const TextStyle(
                  fontSize: 12, color: Colors.redAccent)))
          : null,
      child: vpn.connectionHistory.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text(S.t('no_records'),
                  style: const TextStyle(fontSize: 13, color: Colors.white38))))
          : Column(children: vpn.connectionHistory.asMap().entries.map((e) {
              final r      = e.value;
              final isLast = e.key == vpn.connectionHistory.length - 1;
              return Column(children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _accent.withOpacity(0.20))),
                      child: Icon(Icons.vpn_lock_rounded, size: 16, color: _accent)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.serverName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                              color: _textColor(context))),
                      Text('${r.protocol} · ${r.trafficStr}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10,
                              color: _subTextColor(context).withOpacity(0.45))),
                    ])),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min, children: [
                      Text(r.durationStr, style: TextStyle(
                          fontSize: 11, color: _accent,
                          fontWeight: FontWeight.w600)),
                      Text(
                        '${r.startedAt.day.toString().padLeft(2,'0')}.'
                        '${r.startedAt.month.toString().padLeft(2,'0')} '
                        '${r.startedAt.hour.toString().padLeft(2,'0')}:'
                        '${r.startedAt.minute.toString().padLeft(2,'0')}',
                        style: TextStyle(fontSize: 9,
                            color: _subTextColor(context).withOpacity(0.35))),
                    ]),
                  ])),
                if (!isLast) Divider(height: 0, thickness: 0.5,
                    color: light
                        ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.06)),
              ]);
            }).toList()));
  }
}

// ── Logs Page ─────────────────────────────────────────────────────────────────

class _LogsPage extends StatelessWidget {
  const _LogsPage();
  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context);
    return _SubPage(
      title: S.t('logs'),
      trailing: GestureDetector(
        onTap: vpn.clearLogs,
        child: Text(S.t('clear'), style: const TextStyle(
            fontSize: 12, color: Colors.redAccent))),
      child: GlassBox(tint: Colors.black, tintOpacity: 0.30,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 200, maxHeight: 500),
          child: ListView.builder(
            shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          itemCount: vpn.logs.length, reverse: true,
          itemBuilder: (_, i) {
            final log = vpn.logs[vpn.logs.length - 1 - i];
            final c = log.contains('✗') ? Colors.redAccent
                : log.contains('↻') || log.contains('🐕') ? Colors.orangeAccent
                : log.contains('🤖') ? _accent : Colors.greenAccent;
            return Text(log, style: TextStyle(
                fontFamily: 'monospace', fontSize: 9, color: c));
          }))));
  }
}

// ── About Page ────────────────────────────────────────────────────────────────

class _AboutPage extends StatefulWidget {
  const _AboutPage();
  @override State<_AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<_AboutPage> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _onVersionTap() {
    final now = DateTime.now();
    // Сбрасываем счётчик если прошло больше 2 сек между тапами
    if (_lastTap != null && now.difference(_lastTap!).inSeconds > 2) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;

    if (_tapCount >= 5) {
      _tapCount = 0;
      // Открываем Dev Dashboard
      Navigator.push(context, CupertinoPageRoute(
          builder: (_) => const _DevDashboard()));
    } else if (_tapCount >= 3) {
      // Показываем прогресс (незаметно для обычного пользователя)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🛠 ${5 - _tapCount} ${S.t('dev_taps_hint')}',
            style: const TextStyle(fontSize: 11)),
        duration: const Duration(milliseconds: 800),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
      ));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final upd = Provider.of<VpnProvider>(context).updateAvailable;
    return _SubPage(title: S.t('about_app'), child: Column(children: [
      // ── Баннер обновления (sideload: авто-апдейта нет) ──────────────────
      if (upd != null) GestureDetector(
        onTap: () => UpdateChecker.openDownload(upd),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [
              Color(0xFF43A047), Color(0xFF2E7D32)]),
            boxShadow: [BoxShadow(
                color: const Color(0xFF43A047).withOpacity(0.4), blurRadius: 16)]),
          child: Row(children: [
            const Icon(Icons.system_update_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${S.t('update_available')} · v${upd.version}',
                style: const TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w800)),
              if (upd.notes.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(upd.notes, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11))),
            ])),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10)),
              child: Text(S.t('download'), style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
          ]))),
      // Логотип
      // VLY иконка с неоновым свечением
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Color(0xFFFF2D55).withOpacity(0.4),
                blurRadius: 35, spreadRadius: 2),
            BoxShadow(color: Color(0xFFFF6B35).withOpacity(0.2),
                blurRadius: 60, spreadRadius: 8),
          ]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset('assets/images/vly_icon.png', width: 130, height: 130, fit: BoxFit.contain))),
      const SizedBox(height: 20),
      // Название с градиентом
      ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [Color(0xFFFF2D55), Color(0xFFFF6B35), Color(0xFFFFAA60)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds),
        child: const Text('VLY', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900,
            letterSpacing: 6, color: Colors.white))),
      const SizedBox(height: 8),
      // 5 тапов → Dev Dashboard (незаметно)
      GestureDetector(
        onTap: _onVersionTap,
        onLongPress: () {
          Clipboard.setData(ClipboardData(
              text: 'Vly v$gAppVersion build $gAppBuild'));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.t('version_copied')),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1B2A1B)));
        },
        child: Column(children: [
          Text('v$gAppVersion · build $gAppBuild', style: TextStyle(
              fontSize: 11, color: Colors.white.withOpacity(0.35),
              letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(S.t('hold_to_copy'), style: TextStyle(
              fontSize: 9, color: Colors.white.withOpacity(0.15))),
        ])),
      const SizedBox(height: 24),
      _DetailRow2('🛡', 'Протоколы', 'VLESS, VMess, SS, Trojan, HY2'),
      _DetailRow2('🤖', 'AI Engine', 'Bypass Arsenal · 100 strategies'),
      _DetailRow2('🇷🇺', 'Белые списки', 'antifilter.download · runetfreedom'),
      _DetailRow2('🛡', 'Siberia Shield', 'Connection pacing · Single-tunnel MUX'),
      _DetailRow2('✈️', 'Telegram', 'Fast Protocol · Auto-detect'),
    ]));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  DEVELOPER DASHBOARD  —  скрытый (5 тапов по версии в О приложении)
// ═══════════════════════════════════════════════════════════════════════════════


// ── Bypass Mode Card ─────────────────────────────────────────────────────────
// Карточка выбора метода обхода в настройках AI Bypass
class _BypassModeCard extends StatelessWidget {
  final BypassMode mode;
  final bool       selected;
  final VoidCallback onSelect;
  const _BypassModeCard({required this.mode, required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isRec = mode.isRecommended;
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _accent : Colors.white.withOpacity(0.08),
            width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          // Emoji иконка
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: selected
                  ? _accent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10)),
            child: Center(child: Icon(mode.icon, size: 20,
                color: selected ? _accent : Colors.white70))),
          const SizedBox(width: 12),
          // Название + описание
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(mode.label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: selected ? _accent : Colors.white.withOpacity(0.9)))),
                if (isRec) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.check_rounded, size: 11,
                        color: Color(0xFF00C853))),
                ],
              ]),
              const SizedBox(height: 3),
              Text(mode.description,
                overflow: TextOverflow.visible,
                style: TextStyle(
                fontSize: 11, color: Colors.white.withOpacity(0.5),
                height: 1.3)),
              const SizedBox(height: 4),
              Text(mode.status, style: TextStyle(
                fontSize: 10,
                color: mode.statusColor,
                fontWeight: FontWeight.w500)),
            ])),
          // Индикатор выбора
          if (selected)
            Icon(Icons.check_circle, color: _accent, size: 20)
          else
            Icon(Icons.radio_button_unchecked,
                color: Colors.white.withOpacity(0.2), size: 20),
        ]),
      ),
    );
  }
}

class _DevDashboard extends StatefulWidget {
  const _DevDashboard();
  @override State<_DevDashboard> createState() => _DevDashboardState();
}

class _DevDashboardState extends State<_DevDashboard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final vpn   = Provider.of<VpnProvider>(context);
    final light = Theme.of(context).brightness == Brightness.light;
    return VlyBlobBg(isLight: light, child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text('🛠 Dev Dashboard', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800,
            color: _textColor(context), letterSpacing: 1)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4))),
              child: const Text('DEV', style: TextStyle(
                  fontSize: 9, color: Colors.redAccent,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)))),
        ],
      ),
      body: Column(children: [
        // Tab bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            ...List.generate(4, (i) {
              final label = ['BYPASS','STEALTH','ERRORS','SYSTEM'][i];
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _tab == i ? _accent.withOpacity(0.18) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _tab == i ? _accent.withOpacity(0.5) : Colors.white.withOpacity(0.08))),
                  child: Text(label, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                          color: _tab == i ? _accent : Colors.white38, letterSpacing: 0.5)),
                )));
            }),
          ])),
        const SizedBox(height: 8),
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            if (_tab == 0) _buildBypassTab(vpn),
            if (_tab == 1) _buildStealthTab(vpn),
            if (_tab == 2) _buildErrorsTab(),
            if (_tab == 3) _buildSystemTab(vpn),
          ],
        )),
      ]),
    ));
  }

  // ── Bypass Tab ────────────────────────────────────────────────────────────
  Widget _buildBypassTab(VpnProvider vpn) {
    final blacklist = StrategyBlacklist.allBlocked;
    final stratId   = vpn.devAiAgent.currentStrategyId;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _DevSection('AI BYPASS'),
      _DevRow('Attempt #',         '${vpn.devBypassAttempt}'),
      _DevRow('Node index',        '${vpn.devBypassNodeIdx} / ${vpn.configs.length}'),
      _DevRow('AI running',        '${vpn.devAiAgent.isRunning}'),
      _DevRow('Current strategy',  stratId > 0 ? '#$stratId' : '—'),
      _DevRow('Arsenal size',      '${BypassArsenal.strategies.length} strategies'),
      _DevRow('Recent errors',     '${CrashReporter.recent.length}',
          color: CrashReporter.recent.isEmpty ? null : Colors.orangeAccent),
      if (CrashReporter.recent.isNotEmpty)
        _DevRow('Last error',      CrashReporter.recent.first, color: Colors.orangeAccent),
      const SizedBox(height: 12),
      _DevSection('STRATEGY BLACKLIST (${blacklist.length} banned, 5 min TTL)'),
      if (blacklist.isEmpty)
        const _DevEmptyMsg('Blacklist empty — all strategies available')
      else
        ...blacklist.map((e) {
          final key = e.length > 28 ? e.substring(0, 28) : e;
          return _DevRow(key, 'blocked', color: Colors.redAccent);
        }),
      const SizedBox(height: 12),
      _DevSection('SIBERIA SHIELD'),
      _DevRow('Blocked IPs',       '${SiberiaShield.blockedIpsCount}'),
      _DevRow('Conn timestamps',   '${SiberiaShield.connHostsCount} hosts'),
      _DevRow('Shield enabled',    '${vpn.siberiaShield}'),
      const SizedBox(height: 12),
      _DevSection('BYPASS REPORTER'),
      _DevRow('Server enabled',    'N/A'),
      _DevRow('Server URL',        kControlPlaneUrl),
      const SizedBox(height: 12),
      _DevSection('ACTIONS'),
      _DevBtn('🔍 Test BlockDetector', Colors.blue, () async {
        if (vpn.configs.isEmpty) return;
        final bt = await BlockDetector.detect(vpn.configs[vpn.selectedIndex]);
        if (mounted) _showSnack('Block: ${bt.name}');
      }),
      const SizedBox(height: 6),
      _DevBtn('🧹 Clear blacklist (${blacklist.length})', Colors.orange, () {
        StrategyBlacklist.clear();
        setState(() {});
        _showSnack('Blacklist cleared — all strategies unbanned');
      }),
      const SizedBox(height: 6),
      _DevBtn('🛡 Clear Siberia cooldowns', Colors.teal, () {
        SiberiaShield.clearCooldowns();
        setState(() {});
        _showSnack('Siberia Shield cooldowns cleared');
      }),
      const SizedBox(height: 6),
      _DevBtn('🎯 Test random strategy', Colors.purple, () {
        final s = BypassArsenal.getQuickRandom('tcpReset');
        if (s != null) _showSnack('#${s['id']} · ${s['name']}');
      }),
    ]);
  }

  // ── Stealth Tab ───────────────────────────────────────────────────────────
  Widget _buildStealthTab(VpnProvider vpn) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _DevSection('STEALTH ENGINE 3.0'),
      _DevRow('Stealth mode',     '${vpn.stealthMode}'),
      _DevRow('Fragment',         '${vpn.stealthFragment}'),
      _DevRow('Reality SNI',      '${vpn.stealthRealitySni}'),
      _DevRow('Warm-up',          '${vpn.stealthWarmup}'),
      _DevRow('Siberia Shield',   '${vpn.siberiaShield}'),
      _DevRow('Handshake fails',  '${vpn.stealthHandshakeFails}'),
      const SizedBox(height: 12),
      _DevSection('SNI CACHE'),
      _DevRow('Cached SNI',       StealthEngine.cachedSniPublic),
      _DevRow('SNI index',        '${StealthEngine.sniIndex}'),
      _DevRow('uTLS profile idx', '${StealthEngine.utlsIndexPublic}'),
      _DevRow('RST count',        '${StealthEngine.rstCountPublic}'),
      _DevRow('SNI pool size',    '${kRealitySniPool.length}'),
      const SizedBox(height: 12),
      _DevSection('TELEGRAM PROTOCOL'),
      _DevRow('TG Protocol',      'Auto-detect on connect'),
      _DevRow('TG SNI pool',      '${TelegramProtocol._tgSniPool.length} domains'),
      const SizedBox(height: 12),
      _DevSection('ACTIONS'),
      _DevBtn('🔄 Invalidate SNI cache', Colors.purple, () {
        StealthEngine.invalidateSniCache();
        setState(() {});
        _showSnack('SNI cache cleared');
      }),
      const SizedBox(height: 6),
      _DevBtn('📡 Test pickLiveSni', Colors.indigo, () async {
        final sni = await StealthEngine.pickLiveSni();
        if (mounted) _showSnack('Live SNI: $sni');
      }),
    ]);
  }

  // ── Errors Tab ────────────────────────────────────────────────────────────
  Widget _buildErrorsTab() {
    final codes = VlyErrorCode.values;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _DevSection('ERROR CODES (${codes.length})'),
      ...codes.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          onTap: () { Clipboard.setData(ClipboardData(text: e.code)); _showSnack('${e.code} copied'); },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.07))),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(e.code, style: const TextStyle(
                    fontSize: 9, color: Colors.redAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                Text(e.description, style: const TextStyle(fontSize: 9, color: Colors.white30), maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
            ])),
        ))),
    ]);
  }

  // ── System Tab ────────────────────────────────────────────────────────────
  Widget _buildSystemTab(VpnProvider vpn) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _DevSection('VPN STATE'),
      _DevRow('Status',         vpn.status),
      _DevRow('Is connected',   '${vpn.isConnected}'),
      _DevRow('Is rotating',    '${vpn.devIsRotating}'),
      _DevRow('Fail count',     '${vpn.devFailCount}'),
      _DevRow('Selected node',  '${vpn.selectedIndex} / ${vpn.configs.length}'),
      _DevRow('Auto mode',      '${vpn.isAutoMode}'),
      _DevRow('Kill switch',    '${vpn.killSwitch}'),
      const SizedBox(height: 12),
      _DevSection('BYPASS RULES'),
      _DevRow('Rules version',  '${vpn.bypassRules.devVersion}'),
      _DevRow('Server rules',   '${vpn.bypassRules.devRulesCount}'),
      _DevRow('Domain cache',   '${vpn.bypassRules.devDomainsCount} domains'),
      _DevRow('Domain sync',    vpn.bypassRules.devLastSync?.toString().substring(0,16) ?? '—'),
      const SizedBox(height: 12),
      _DevSection('PROFILES'),
      _DevRow('Active profile', vpn.activeProfileName),
      _DevRow('Profiles count', '${vpn.profiles.length}'),
      _DevRow('Sub links',      '${vpn.subLinks.length}'),
      const SizedBox(height: 12),
      _DevSection('ACTIONS'),
      _DevBtn('🔃 Force sync rules', Colors.blue, () {
        vpn.syncRules();
        _showSnack('Rules sync started');
      }),
      const SizedBox(height: 6),
      _DevBtn('📋 Copy all logs', Colors.green, () {
        Clipboard.setData(ClipboardData(text: vpn.logs.join('\n')));
        _showSnack('${vpn.logs.length} logs copied');
      }),
      const SizedBox(height: 6),
      _DevBtn('🗑 Clear logs', Colors.red, () {
        vpn.clearLogs();
        setState(() {});
        _showSnack('Logs cleared');
      }),
    ]);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF1A1A2E),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ── Dev Dashboard helpers ────────────────────────────────────────────────────

class _DevSection extends StatelessWidget {
  final String text;
  const _DevSection(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
    child: Text(text, style: TextStyle(
        fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700,
        color: _accent.withOpacity(0.7))));
}

class _DevRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _DevRow(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      SizedBox(width: 140, child: Text(label, style: const TextStyle(
          fontSize: 10, color: Colors.white38))),
      Expanded(child: Text(value, style: TextStyle(
          fontSize: 10, color: color ?? Colors.white60,
          fontFamily: 'monospace', fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis)),
    ]));
}

class _DevEmptyMsg extends StatelessWidget {
  final String text;
  const _DevEmptyMsg(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.white24)));
}

class _DevBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DevBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))));
}



class _SubPage extends StatelessWidget {
  final String title; final Widget child; final Widget? trailing;
  const _SubPage({required this.title, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) => VlyScaffold(
    title: title,
    trailing: trailing,
    body: ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        context.pagePadding.left.clamp(16.0, double.infinity),
        12,
        context.pagePadding.right.clamp(16.0, double.infinity),
        40,
      ),
      children: [child],
    ),
  );
}

class _SubSection extends StatelessWidget {
  final String text;
  const _SubSection(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
    child: Text(text, style: TextStyle(
        fontSize: 9, letterSpacing: 2,
        color: _subTextColor(context).withOpacity(0.4),
        fontWeight: FontWeight.w600)));
}

// ── Hint Button ⓘ — маленькая кнопка подсказки ───────────────────────────────
// При нажатии показывает tooltip-like снекбар с объяснением настройки

class _HintButton extends StatelessWidget {
  final String hint;
  const _HintButton({required this.hint});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Показываем overlay с подсказкой
        final overlay = Overlay.of(context);
        final entry = OverlayEntry(builder: (ctx) => _HintOverlay(hint: hint));
        overlay.insert(entry);
        Future.delayed(const Duration(seconds: 4), entry.remove);
      },
      child: Container(
        width: 18, height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.15))),
        child: const Center(child: Text('i',
            style: TextStyle(fontSize: 10, color: Colors.white38,
                fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))),
      ),
    );
  }
}

class _HintOverlay extends StatefulWidget {
  final String hint;
  const _HintOverlay({required this.hint});
  @override State<_HintOverlay> createState() => _HintOverlayState();
}

class _HintOverlayState extends State<_HintOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
    // Начинаем fade-out за 0.5 сек до удаления
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _ac.reverse();
    });
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Позиционируем снизу экрана над навигационной панелью
      bottom: MediaQuery.of(context).padding.bottom + 80,
      left: 16, right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E).withOpacity(0.97),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
                BoxShadow(color: _accent.withOpacity(0.05), blurRadius: 40),
              ]),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 16, color: _accent),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.hint,
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85),
                      height: 1.4))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Whitelist Bypass Tester ─────────────────────────────────────────────────
// Тестирует работоспособность обхода белых списков

class _WhitelistTesterPage extends StatefulWidget {
  const _WhitelistTesterPage();
  @override State<_WhitelistTesterPage> createState() => _WhitelistTesterPageState();
}

class _WhitelistTesterPageState extends State<_WhitelistTesterPage> {
  // Ключевые домены провайдер — должны быть доступны БЕЗ VPN
  static const _ruDomains = [
    ('gosuslugi.ru',     '🏛 Госуслуги'),
    ('mos.ru',           '🏙 Mos.ru (Москва)'),
    ('nalog.ru',         '💼 ФНС (налоги)'),
    ('pfr.gov.ru',       '🏦 СФР (пенсии)'),
    ('cbr.ru',           '🏦 Банк России'),
    ('sberbank.ru',      '💚 Сбербанк'),
    ('tbank.ru',         '🟡 Т-Банк'),
    ('vk.com',           '🔵 VK'),
    ('ok.ru',            '🟠 Одноклассники'),
    ('mail.ru',          '✉️ Mail.ru'),
    ('yandex.ru',        '🔴 Яндекс'),
    ('2gis.ru',          '🗺 2ГИС'),
  ];

  // Домены которые БЛОКИРУЮТСЯ провайдер — должны работать ЧЕРЕЗ VPN
  static const _blockedDomains = [
    ('instagram.com',    '📸 Instagram'),
    ('twitter.com',      '🐦 X (Twitter)'),
    ('facebook.com',     '👥 Facebook'),
    ('discord.com',      '🎮 Discord'),
    ('reddit.com',       '🤖 Reddit'),
    ('medium.com',       '📝 Medium'),
    ('soundcloud.com',   '🎵 SoundCloud'),
  ];

  final Map<String, int?> _results = {};
  bool _testing = false;

  Future<void> _runTest() async {
    setState(() { _testing = true; _results.clear(); });
    final allDomains = [..._ruDomains, ..._blockedDomains];
    for (final (domain, _) in allDomains) {
      final ms = await _pingDomain(domain);
      if (mounted) setState(() => _results[domain] = ms);
    }
    if (mounted) setState(() => _testing = false);
  }

  Future<int?> _pingDomain(String domain) async {
    try {
      final sw = Stopwatch()..start();
      final s = await Socket.connect(domain, 443,
          timeout: const Duration(seconds: 4));
      sw.stop();
      await s.close();
      return sw.elapsedMilliseconds;
    } catch (_) { return null; }
  }

  Widget _legendRow(Color color, IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(
          fontSize: 11.5, color: Colors.white70))),
    ]));

  Widget _domainRow(String domain, String label, bool expectReachable) {
    final result = _results[domain];
    final tested = _results.containsKey(domain);
    final reachable = result != null;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!tested) {
      statusColor = Colors.white24;
      statusText  = '—';
      statusIcon  = Icons.circle_outlined;
    } else if (reachable && expectReachable) {
      // RU домен доступен — правильно
      statusColor = Colors.greenAccent;
      statusText  = '${result}ms';
      statusIcon  = Icons.check_circle_rounded;
    } else if (!reachable && !expectReachable) {
      // Заблокированный недоступен без VPN — правильно
      statusColor = Colors.blueAccent;
      statusText  = S.t('status_blocked');
      statusIcon  = Icons.shield_rounded;
    } else if (!reachable && expectReachable) {
      // RU домен недоступен — ПРОБЛЕМА (VPN режет РФ трафик?)
      statusColor = Colors.redAccent;
      statusText  = S.t('status_fail');
      statusIcon  = Icons.error_rounded;
    } else {
      // Заблокированный доступен — VPN не подключён
      statusColor = Colors.orangeAccent;
      statusText  = '${result}ms';
      statusIcon  = Icons.warning_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.15))),
      child: Row(children: [
        Icon(statusIcon, size: 14, color: statusColor),
        const SizedBox(width: 10),
        Expanded(child: Text('$label  $domain',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
            maxLines: 2)),
        Text(statusText,
            style: TextStyle(fontSize: 11, color: statusColor,
                fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VlyScaffold(
      title: S.t('whitelist_test'),
      trailing: GestureDetector(
        onTap: _testing ? null : _runTest,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _accent.withOpacity(0.4))),
          child: Text(_testing ? S.t('testing_btn') : S.t('run_btn'),
              style: TextStyle(fontSize: 11, color: _accent,
                  fontWeight: FontWeight.bold)),
        )),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _InfoCard(
            icon: Icons.info_outline_rounded,
            text: S.t('info_wl_test'),
          ),
          const SizedBox(height: 14),

          // Легенда цветов — чтобы результаты читались однозначно.
          _SubSection(S.t('legend_caps')),
          _legendRow(Colors.greenAccent, Icons.check_circle_rounded, S.t('legend_ok')),
          _legendRow(Colors.blueAccent, Icons.shield_rounded, S.t('legend_blocked')),
          _legendRow(Colors.redAccent, Icons.error_rounded, S.t('legend_fail')),
          _legendRow(Colors.orangeAccent, Icons.warning_rounded, S.t('legend_vpnoff')),
          const SizedBox(height: 16),

          _SubSection(S.t('ru_domains_caps')),
          ..._ruDomains.map((e) => _domainRow(e.$1, e.$2, true)),

          const SizedBox(height: 16),
          _SubSection(S.t('blocked_caps')),
          ..._blockedDomains.map((e) => _domainRow(e.$1, e.$2, false)),

          if (_testing) ...[
            const SizedBox(height: 16),
            const Center(child: CupertinoActivityIndicator()),
            const SizedBox(height: 8),
            Center(child: Text(S.t('checking_avail'),
                style: TextStyle(fontSize: 11, color: Colors.white38))),
          ],
        ],
      ),
    );
  }
}


class _SwitchRow extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;
  final String? hint; // текст подсказки — показывается при нажатии ⓘ
  const _SwitchRow({required this.icon, required this.iconColor,
      required this.title, required this.subtitle,
      required this.value, required this.onChanged,
      this.trailing, this.hint});
  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: light ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: light ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: iconColor.withOpacity(0.25))),
          child: Icon(icon, size: 17, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(title, style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w500, color: _textColor(context)))),
            // Кнопка подсказки ⓘ — появляется если hint задан
            if (hint != null) ...[
              const SizedBox(width: 4),
              _HintButton(hint: hint!),
            ],
          ]),
          Text(subtitle, style: TextStyle(fontSize: 10,
              color: _subTextColor(context).withOpacity(0.5))),
        ])),
        trailing ?? CupertinoSwitch(
            value: value, activeColor: _accent,
            onChanged: onChanged),
      ]));
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon; final Color iconColor;
  final String title, subtitle, actionLabel;
  final VoidCallback? onTap;
  const _ActionRow({required this.icon, required this.iconColor,
      required this.title, required this.subtitle,
      required this.actionLabel, this.onTap});
  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: light ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(title, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w500, color: _textColor(context))),
          Text(subtitle, style: TextStyle(fontSize: 10,
              color: _subTextColor(context).withOpacity(0.5))),
        ])),
        GestureDetector(onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: iconColor.withOpacity(0.3))),
            child: Text(actionLabel, style: TextStyle(
                fontSize: 10, color: iconColor, fontWeight: FontWeight.bold,
                letterSpacing: 1)))),
      ]));
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.label,
      required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          color.withOpacity(0.65), color.withOpacity(0.35)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.20), blurRadius: 14)]),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: 0.5)),
      ])));
}

class _InfoCard extends StatelessWidget {
  final IconData icon; final String text;
  const _InfoCard({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.10))),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.white30),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(
          fontSize: 11, color: Colors.white38, height: 1.5))),
    ]));
}

class _DetailRow2 extends StatelessWidget {
  final String emoji, label, value;
  const _DetailRow2(this.emoji, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white38)),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 12,
          color: _textColor(context), fontWeight: FontWeight.w600)),
    ]));
}

// ── Settings micro-widgets ────────────────────────────────────────────────────

// ── Skin Picker ──────────────────────────────────────────────────────────────

class _SkinPicker extends StatelessWidget {
  final AppProvider app;
  const _SkinPicker({required this.app});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.15,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: VlySkin.all.length + 1,
        itemBuilder: (ctx, i) {
          if (i == VlySkin.all.length) {
            return _SkinGridTile(
              selected: app.skinId == VlySkinId.custom,
              customAccent: app.skin.accent,
              onTap: () => Navigator.push(context, PageRouteBuilder(
                pageBuilder: (_, a, __) => const _CustomThemeEditor(),
                transitionsBuilder: (_, a, __, c) => SlideTransition(
                  position: Tween(begin: const Offset(0,1), end: Offset.zero)
                      .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                  child: c))),
            );
          }
          final skin = VlySkin.all[i];
          return _SkinGridTile(
            skin: skin,
            selected: app.skinId == skin.id,
            onTap: () => app.setSkin(skin.id),
          );
        },
      ),
    );
  }
}

// Плитка темы — РЕАЛЬНОЕ мини-превью (градиент + акцентные блобы), без эмодзи.
// Если skin == null — это плитка «My Theme» (кастомный редактор).
class _SkinGridTile extends StatelessWidget {
  final VlySkin?    skin;          // null = кастомная плитка
  final bool         selected;
  final VoidCallback onTap;
  final Color?       customAccent;  // акцент для рамки кастомной плитки

  const _SkinGridTile({
    this.skin,
    required this.selected,
    required this.onTap,
    this.customAccent,
  });

  @override
  Widget build(BuildContext context) {
    final a = skin?.accent ?? customAccent ?? const Color(0xFF00E5FF);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? a : Colors.white.withOpacity(0.08),
            width: selected ? 2 : 1),
          boxShadow: selected
            ? [BoxShadow(color: a.withOpacity(0.45), blurRadius: 18, spreadRadius: 1)]
            : [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8,
                offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: skin == null ? _customPreview(a) : _themePreview(skin!, a, selected),
        ),
      ),
    );
  }

  // Превью реальной темы
  static Widget _themePreview(VlySkin s, Color a, bool selected) {
    Color blob(int i) => i < s.blobs.length ? s.blobs[i] : s.accentSecondary;
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [s.bgDark, s.bgGradientMid, s.bgGradientEnd]))),
      Positioned(left: -18, top: -14, child: _blob(blob(2), 64)),
      Positioned(right: -22, bottom: 16, child: _blob(blob(3), 76)),
      Positioned(right: 12, top: -10, child: _blob(s.accentSecondary, 38)),
      Align(alignment: Alignment.bottomCenter, child: Container(height: 44,
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.55)])))),
      Positioned(left: 11, right: 11, bottom: 10, child: Row(children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle,
          color: a, boxShadow: [BoxShadow(color: a.withOpacity(0.6), blurRadius: 6)])),
        const SizedBox(width: 7),
        Expanded(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white.withOpacity(0.95),
            fontSize: 12, fontWeight: FontWeight.w700))),
      ])),
      if (selected) Positioned(right: 8, top: 8, child: Container(
        width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle,
          color: a, boxShadow: [BoxShadow(color: a.withOpacity(0.6), blurRadius: 8)]),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white))),
    ]);
  }

  // Превью кастомной плитки
  static Widget _customPreview(Color a) => Stack(fit: StackFit.expand, children: [
    DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [const Color(0xFF15151F), a.withOpacity(0.18), const Color(0xFF15151F)]))),
    Center(child: Icon(Icons.palette_outlined, color: a.withOpacity(0.9), size: 30)),
    Align(alignment: Alignment.bottomCenter, child: Container(height: 40,
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black.withOpacity(0.5)])))),
    Positioned(left: 11, right: 11, bottom: 10, child: Text('My Theme',
      maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(color: Colors.white.withOpacity(0.95),
        fontSize: 12, fontWeight: FontWeight.w700))),
  ]);

  static Widget _blob(Color c, double s) => Container(width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(
      colors: [c.withOpacity(0.55), c.withOpacity(0.0)])));
}

// ═══════════════════════════════════════════════════════════════════════════
//  CUSTOM THEME EDITOR — редактор собственной темы
// ═══════════════════════════════════════════════════════════════════════════
class _CustomThemeEditor extends StatefulWidget {
  const _CustomThemeEditor();
  @override State<_CustomThemeEditor> createState() => _CustomThemeEditorState();
}

class _CustomThemeEditorState extends State<_CustomThemeEditor> {
  late AppProvider _app;

  @override
  void initState() {
    super.initState();
    _app = Provider.of<AppProvider>(context, listen: false);
  }

  Future<void> _pickPhoto() async {
    try {
      // Системный выбор изображения/GIF из галереи (Android Photo Picker —
      // разрешений не требует). Файл копируется плагином в хранилище приложения,
      // поэтому путь стабилен между запусками.
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 92);
      if (file == null) return; // пользователь отменил
      final path = file.path;
      if (!File(path).existsSync()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.t('file_not_found')), backgroundColor: Colors.red));
        return;
      }
      final ext  = path.split('.').last.toLowerCase();
      final type = ext == 'gif' ? 'gif' : 'photo';
      await _app.saveCustomTheme(mediaPath: path, mediaType: type);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.t('error')}: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _clearPhoto() async {
    await _app.clearCustomMedia();
    if (mounted) setState(() {});
  }

  // Поделиться темой: копируем код в буфер и открываем системный share-лист.
  Future<void> _shareTheme(AppProvider app) async {
    final code = app.exportThemeCode();
    await Clipboard.setData(ClipboardData(text: code));
    try {
      await const MethodChannel('vly_vpn/share').invokeMethod('share', {
        'text': '${S.t('share_theme_msg')}\n\n$code',
        'subject': 'Vly Theme',
      });
    } catch (_) {/* нет нативного share — код уже в буфере обмена */}
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.t('theme_code_copied'))));
  }

  // Импорт темы друга: вставить код → применить.
  Future<void> _importTheme(AppProvider app) async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(S.t('import_theme'),
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: ctrl, autofocus: true, maxLines: 3, minLines: 1,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            hintText: S.t('paste_theme_code'),
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true, fillColor: Colors.white.withOpacity(0.07),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text(S.t('cancel'), style: const TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text(S.t('ok'), style: TextStyle(color: _accent))),
        ]));
    if (code == null || code.isEmpty) return;
    final ok = await app.importThemeCode(code);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? S.t('theme_imported') : S.t('invalid_theme_code')),
      backgroundColor: ok ? null : Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);
    return VlyBlobBg(child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text(S.t('my_theme'),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: Colors.white)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, GlassAppBar.totalHeight(context) + 8, 16, 40),
        children: [

          // ── ПРЕВЬЮ — живой мини-макет главного экрана с выбранной темой ──
          // Показывает реальный фон (фото/GIF или блобы), кнопку питания в
          // стиле приложения и акцентные чипы — как будет выглядеть на самом деле.
          Container(
            height: 168,
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: app.customBg,
              border: Border.all(color: app.customAccent.withOpacity(0.35)),
              boxShadow: [BoxShadow(
                  color: app.customAccent.withOpacity(0.25), blurRadius: 20)],
            ),
            child: Stack(fit: StackFit.expand, children: [
              // Слой фона: фото/GIF если выбрано, иначе градиент из блобов
              if (app.hasCustomMedia)
                Image.file(File(app.customMediaPath), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox())
              else
                DecoratedBox(decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [
                      app.customBlob1.withOpacity(0.65),
                      app.customBg,
                      app.customBlob2.withOpacity(0.55),
                    ]))),
              // Затемнение поверх фото, чтобы кнопка читалась
              if (app.hasCustomMedia)
                DecoratedBox(decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.15),
                             Colors.black.withOpacity(0.45)]))),
              // Контент: кнопка питания в стиле приложения + статус + чипы
              Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                  _PreviewPowerButton(
                    accent: app.customAccent, accent2: app.customAccent2,
                    style: app.customButtonStyle),
                  const SizedBox(height: 12),
                  Text(S.t('connected').toUpperCase(), style: TextStyle(
                      color: app.customAccent, fontSize: 11,
                      fontWeight: FontWeight.w800, letterSpacing: 2.5,
                      shadows: [Shadow(color: app.customAccent.withOpacity(0.5),
                          blurRadius: 10)])),
                  const SizedBox(height: 10),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _PreviewChip('AUTO', app.customAccent),
                    const SizedBox(width: 6),
                    _PreviewChip('STEALTH', app.customAccent2),
                  ]),
                ])),
            ])),
          Padding(
            padding: const EdgeInsets.only(bottom: 18, left: 4),
            child: Text(S.t('applies_immediately'),
              style: TextStyle(color: Colors.white.withOpacity(0.35),
                  fontSize: 11))),

          // ── ЦВЕТ АКЦЕНТА ────────────────────────────────────────────────
          _SectionLabel(S.t('accent_color')),
          _ColorRow(label: S.t('accent'), color: app.customAccent,
            onTap: () => _showColorPicker(context, app.customAccent, (c) {
              app.saveCustomTheme(accent: c); setState((){});
            })),
          _ColorRow(label: S.t('accent2'), color: app.customAccent2,
            onTap: () => _showColorPicker(context, app.customAccent2, (c) {
              app.saveCustomTheme(accent2: c); setState((){});
            })),

          const SizedBox(height: 16),

          // ── ЦВЕТ ФОНА ────────────────────────────────────────────────────
          _SectionLabel(S.t('bg_color')),
          _ColorRow(label: S.t('bg'), color: app.customBg,
            onTap: () => _showColorPicker(context, app.customBg, (c) {
              app.saveCustomTheme(bg: c); setState((){});
            })),
          _ColorRow(label: S.t('blob1'), color: app.customBlob1,
            onTap: () => _showColorPicker(context, app.customBlob1, (c) {
              app.saveCustomTheme(blob1: c); setState((){});
            })),
          _ColorRow(label: S.t('blob2'), color: app.customBlob2,
            onTap: () => _showColorPicker(context, app.customBlob2, (c) {
              app.saveCustomTheme(blob2: c); setState((){});
            })),

          const SizedBox(height: 16),

          // ── СТИЛЬ КНОПКИ ПИТАНИЯ ──────────────────────────────────────────
          _SectionLabel(S.t('button_style')),
          Row(children: PowerButtonStyle.values.map((s) {
            final selected = app.customButtonStyle == s;
            return Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () { app.saveCustomTheme(buttonStyle: s); setState((){}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: selected
                        ? app.customAccent.withOpacity(0.14)
                        : Colors.white.withOpacity(0.04),
                    border: Border.all(
                      color: selected
                          ? app.customAccent.withOpacity(0.6)
                          : Colors.white.withOpacity(0.08),
                      width: selected ? 1.5 : 1)),
                  child: Column(children: [
                    _MiniButtonPreview(style: s, accent: app.customAccent),
                    const SizedBox(height: 6),
                    Text(S.t('btn_style_${s.name}'), style: TextStyle(
                        fontSize: 10,
                        color: selected ? app.customAccent : Colors.white54,
                        fontWeight: FontWeight.w600)),
                  ])))));
          }).toList()),

          const SizedBox(height: 16),

          // ── ФОН — ФОТО / GIF ─────────────────────────────────────────────
          _SectionLabel(S.t('photo_gif_bg')),
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withOpacity(0.05),
                border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: Row(children: [
                Icon(Icons.photo_library_outlined,
                    color: _accent, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(S.t('choose_photo_gif'),
                    style: TextStyle(color: Colors.white.withOpacity(0.9),
                        fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    app.hasCustomMedia
                      ? app.customMediaPath.split('/').last
                      : S.t('photo_hint'),
                    style: TextStyle(
                      color: app.hasCustomMedia
                        ? _accent : Colors.white.withOpacity(0.4),
                      fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                if (app.hasCustomMedia)
                  GestureDetector(
                    onTap: _clearPhoto,
                    child: const Icon(Icons.close, color: Colors.redAccent, size: 18))
                else
                  Icon(Icons.add_circle_outline,
                      color: _accent.withOpacity(0.6), size: 20),
              ])),
          ),

          // Предпросмотр медиа
          if (app.hasCustomMedia) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(app.customMediaPath),
                height: 100, width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  color: Colors.white.withOpacity(0.05),
                  child: const Center(child: Icon(Icons.broken_image,
                      color: Colors.white30))),
              )),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 16),

          // ── ОБМЕН ТЕМАМИ ─────────────────────────────────────────────────
          _SectionLabel(S.t('share_theme_caps')),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => _shareTheme(app),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: app.customAccent.withOpacity(0.14),
                  border: Border.all(color: app.customAccent.withOpacity(0.4))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.ios_share_rounded, size: 16, color: app.customAccent),
                  const SizedBox(width: 8),
                  Text(S.t('share_theme'), style: TextStyle(
                      color: app.customAccent, fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
                ])))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => _importTheme(app),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: Colors.white.withOpacity(0.14))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.download_rounded, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(S.t('import_theme'), style: const TextStyle(
                      color: Colors.white70, fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
                ])))),
          ]),

          const SizedBox(height: 24),

          // ── ГОТОВО (тема уже активна — кнопка просто закрывает) ──────────
          GestureDetector(
            onTap: () {
              app.setSkin(VlySkinId.custom);
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [
                  app.customAccent, app.customAccent2])),
              child: Text(S.t('done'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5))),
          ),
        ],
      ),
    ));
  }

  void _showColorPicker(BuildContext ctx, Color current, ValueChanged<Color> onChanged) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ColorPickerSheet(current: current, onChanged: onChanged));
  }
}

// Кнопка питания для превью — повторяет стиль реальной _LiquidGlassButton
// под выбранный PowerButtonStyle (через общий _powerBtnStyleParams), статична.
class _PreviewPowerButton extends StatelessWidget {
  final Color accent, accent2;
  final PowerButtonStyle style;
  const _PreviewPowerButton({
    required this.accent, required this.accent2,
    this.style = PowerButtonStyle.glass});
  @override
  Widget build(BuildContext context) {
    final st = _powerBtnStyleParams(style, false);
    final List<Color> core = st.solidFill
        ? [accent.withOpacity(0.85), accent.withOpacity(0.55), accent.withOpacity(0.35)]
        : st.ring
            ? [Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.18)]
            : [Colors.white.withOpacity(0.24), accent.withOpacity(0.20),
               Colors.black.withOpacity(0.22)];
    return Container(
      width: 62, height: 62,
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
        // Свечение масштабируем под размер превью (кнопка ~вдвое меньше реальной).
        BoxShadow(color: accent.withOpacity(0.55), blurRadius: st.glowA * 0.5),
        BoxShadow(color: accent.withOpacity(0.25), blurRadius: st.glowB * 0.5),
      ]),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4), radius: 1.0, colors: core),
          border: Border.all(
            color: st.ring ? accent.withOpacity(0.9) : accent.withOpacity(0.6),
            width: st.ring ? st.border : (st.solidFill ? 0.0 : 1.5))),
        child: Icon(Icons.power_settings_new_rounded,
            color: st.solidFill ? Colors.white : accent, size: 28,
            shadows: [Shadow(color: accent.withOpacity(0.6), blurRadius: 14)])));
  }
}

// Мини-превью кнопки для чипа выбора стиля (маленькая, 28px).
class _MiniButtonPreview extends StatelessWidget {
  final PowerButtonStyle style; final Color accent;
  const _MiniButtonPreview({required this.style, required this.accent});
  @override
  Widget build(BuildContext context) {
    final st = _powerBtnStyleParams(style, false);
    final List<Color> core = st.solidFill
        ? [accent.withOpacity(0.85), accent.withOpacity(0.45)]
        : st.ring
            ? [Colors.transparent, Colors.black.withOpacity(0.18)]
            : [Colors.white.withOpacity(0.22), accent.withOpacity(0.18)];
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
        BoxShadow(color: accent.withOpacity(0.5), blurRadius: st.glowA * 0.28),
      ]),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4), radius: 1.0, colors: core),
          border: Border.all(
            color: st.ring ? accent.withOpacity(0.9) : accent.withOpacity(0.55),
            width: st.ring ? 2.4 : (st.solidFill ? 0.0 : 1.0))),
        child: Icon(Icons.power_settings_new_rounded, size: 14,
            color: st.solidFill ? Colors.white : accent)));
  }
}

// Мини-чип статуса для превью (AUTO / STEALTH).
class _PreviewChip extends StatelessWidget {
  final String label; final Color color;
  const _PreviewChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.45))),
    child: Text(label, style: TextStyle(color: color, fontSize: 8,
        fontWeight: FontWeight.w800, letterSpacing: 1)));
}

// Строка выбора цвета
class _ColorRow extends StatelessWidget {
  final String label;
  final Color  color;
  final VoidCallback onTap;
  const _ColorRow({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)])),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
        Text(
          '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11,
              fontFamily: 'monospace')),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 18),
      ])));
}

// Секция-заголовок
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(text, style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: Colors.white.withOpacity(0.4),
      letterSpacing: 1.2)));
}

// Профессиональный HSV color picker: SV-квадрат + слайдер оттенка + быстрые
// свотчи + HEX-ввод. Живой предпросмотр, точный подбор цвета жестами.
class _ColorPickerSheet extends StatefulWidget {
  final Color current;
  final ValueChanged<Color> onChanged;
  const _ColorPickerSheet({required this.current, required this.onChanged});
  @override State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv;
  late TextEditingController _hexCtrl;

  // Быстрые пресеты для мгновенного выбора
  static const _palette = [
    Color(0xFFFF4D4D), Color(0xFFFF6B35), Color(0xFFFFD700), Color(0xFF00E676),
    Color(0xFF00B4D8), Color(0xFF00E5FF), Color(0xFF7C4DFF), Color(0xFFD500F9),
    Color(0xFFFF4081), Color(0xFFFFB5D8), Color(0xFF00FF9F), Color(0xFFFF9800),
    Color(0xFFFFFFFF), Color(0xFFBDBDBD), Color(0xFF757575), Color(0xFF212121),
  ];

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.current);
    _hexCtrl = TextEditingController(text: _hex(widget.current));
  }

  @override
  void dispose() { _hexCtrl.dispose(); super.dispose(); }

  String _hex(Color c) =>
      c.value.toRadixString(16).substring(2).toUpperCase();

  // Тема оперирует непрозрачными цветами.
  Color get _color => _hsv.toColor().withOpacity(1);

  void _emit({bool syncHex = true}) {
    if (syncHex) _hexCtrl.text = _hex(_color);
    widget.onChanged(_color);
  }

  void _setSV(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = 1 - (local.dy / size.height).clamp(0.0, 1.0);
    setState(() => _hsv = _hsv.withSaturation(s).withValue(v));
    _emit();
  }

  void _setHue(double dx, double width) {
    final h = (dx / width).clamp(0.0, 1.0) * 360;
    setState(() => _hsv = _hsv.withHue(h));
    _emit();
  }

  void _pickSwatch(Color c) {
    setState(() => _hsv = HSVColor.fromColor(c));
    _emit();
  }

  @override
  Widget build(BuildContext ctx) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF15151F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Handle
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 18),

        // ── SV-квадрат (насыщенность × яркость) ──────────────────────────
        LayoutBuilder(builder: (_, c) {
          final size = Size(c.maxWidth, 180);
          return GestureDetector(
            onPanDown: (d) => _setSV(d.localPosition, size),
            onPanUpdate: (d) => _setSV(d.localPosition, size),
            child: SizedBox(
              width: size.width, height: size.height,
              child: Stack(children: [
                Positioned.fill(child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CustomPaint(painter: _SVPainter(_hsv.hue)))),
                Positioned(
                  left: (_hsv.saturation * size.width - 10)
                      .clamp(-2.0, size.width - 18),
                  top: ((1 - _hsv.value) * size.height - 10)
                      .clamp(-2.0, size.height - 18),
                  child: IgnorePointer(child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: color,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 4)])))),
              ])),
          );
        }),
        const SizedBox(height: 18),

        // ── Слайдер оттенка (радуга) ─────────────────────────────────────
        LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth;
          return GestureDetector(
            onPanDown: (d) => _setHue(d.localPosition.dx, w),
            onPanUpdate: (d) => _setHue(d.localPosition.dx, w),
            child: SizedBox(width: w, height: 24, child: Stack(children: [
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: [
                  Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
                  Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF),
                  Color(0xFFFF0000)])))),
              Positioned(
                left: (_hsv.hue / 360 * w - 12).clamp(-2.0, w - 22),
                top: -1,
                child: IgnorePointer(child: Container(
                  width: 24, height: 26, decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white,
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 3)])))),
            ])),
          );
        }),
        const SizedBox(height: 20),

        // ── Быстрые пресеты ──────────────────────────────────────────────
        Wrap(spacing: 10, runSpacing: 10, children: _palette.map((sw) {
          final sel = _color.value == sw.value;
          return GestureDetector(
            onTap: () => _pickSwatch(sw),
            child: Container(width: 34, height: 34,
              decoration: BoxDecoration(color: sw,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: sel ? Colors.white : Colors.white12,
                  width: sel ? 2.5 : 1))));
        }).toList()),
        const SizedBox(height: 18),

        // ── HEX + предпросмотр + OK ──────────────────────────────────────
        Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12)])),
          const SizedBox(width: 12),
          Expanded(child: Row(children: [
            Text('#', style: TextStyle(
                color: Colors.white.withOpacity(0.5), fontSize: 15,
                fontFamily: 'monospace', fontWeight: FontWeight.w700)),
            Expanded(child: TextField(
              controller: _hexCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 15,
                  fontFamily: 'monospace', fontWeight: FontWeight.w700),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                filled: true, fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none)),
              onChanged: (v) {
                final h = v.replaceAll('#', '').trim();
                if (h.length == 6) {
                  try {
                    final c = Color(int.parse('FF$h', radix: 16));
                    setState(() => _hsv = HSVColor.fromColor(c));
                    _emit(syncHex: false);
                  } catch (_) {}
                }
              },
            )),
          ])),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: _accent, borderRadius: BorderRadius.circular(10)),
              child: const Text('OK', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)))),
        ]),
      ]));
  }
}

// Заливка SV-квадрата: слева-направо белый→чистый оттенок, сверху-вниз
// прозрачный→чёрный (модель HSV).
class _SVPainter extends CustomPainter {
  final double hue;
  _SVPainter(this.hue);
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..shader = LinearGradient(colors: [
      Colors.white, HSVColor.fromAHSV(1, hue, 1, 1).toColor()]).createShader(r));
    c.drawRect(r, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black]).createShader(r));
  }
  @override bool shouldRepaint(_SVPainter o) => o.hue != hue;
}

class _SH extends StatelessWidget {
  final String t; final BuildContext ctx;
  const _SH(this.t, this.ctx);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
    child: Text(t, style: TextStyle(fontSize: 10, color: _subTextColor(ctx).withOpacity(0.45), fontWeight: FontWeight.bold, letterSpacing: 2)));
}

class _GT extends StatelessWidget {
  final IconData icon; final String title, sub; final Widget trail;
  final bool last; final BuildContext context; final VoidCallback? onTap;
  const _GT({required this.icon, required this.title, required this.sub,
      required this.trail, required this.last, required this.context, this.onTap});
  @override
  Widget build(BuildContext ctx) => Column(children: [
    GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(9),
          child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(width: 34, height: 34,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white.withOpacity(0.14))),
              child: Icon(icon, size: 17, color: _textColor(context).withOpacity(0.7))))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, color: _textColor(context), fontWeight: FontWeight.w500)),
          Text(sub, style: TextStyle(fontSize: 10, color: _subTextColor(context).withOpacity(0.5))),
        ])),
        trail,
      ]))),
    if (!last) Divider(height: 0, thickness: 0.5, color: Theme.of(ctx).brightness == Brightness.light ? Colors.black.withOpacity(0.07) : Colors.white.withOpacity(0.07), indent: 60),
  ]);
}

class _GI extends StatelessWidget {
  final TextEditingController ctrl; final String hint; final BuildContext context;
  const _GI({required this.ctrl, required this.hint, required this.context});
  @override
  Widget build(BuildContext ctx) => ClipRRect(borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: TextField(controller: ctrl,
        style: TextStyle(fontSize: 12, color: _textColor(context)),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(fontSize: 11, color: _subTextColor(context).withOpacity(0.35)),
          filled: true, fillColor: Theme.of(ctx).brightness == Brightness.light ? Colors.black.withOpacity(0.04) : Colors.white.withOpacity(0.07),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _accent, width: 1.2)),
        ))));
}

class _GB extends StatelessWidget {
  final String label; final Color color; final VoidCallback? onTap;
  const _GB({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: ClipRRect(borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(width: double.infinity, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.35))),
          child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold, letterSpacing: 1.2))))));
}

class _GIB extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _GIB({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: ClipRRect(borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
          child: Icon(icon, size: 18, color: Colors.white54)))));
}

class _SR extends StatelessWidget {
  final String url, name; final VoidCallback onDel, onRen; final BuildContext context;
  const _SR({required this.url, required this.name, required this.onDel, required this.onRen, required this.context});
  @override
  Widget build(BuildContext ctx) => Padding(padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(Icons.rss_feed, size: 13, color: _subTextColor(context).withOpacity(0.4)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: TextStyle(fontSize: 12, color: _textColor(context).withOpacity(0.7), fontWeight: FontWeight.w500)),
        Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: _subTextColor(context).withOpacity(0.35))),
      ])),
      GestureDetector(onTap: onRen, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.edit_outlined, size: 15, color: _subTextColor(context).withOpacity(0.5)))),
      GestureDetector(onTap: onDel, child: const Icon(Icons.close, size: 16, color: Colors.redAccent)),
    ]));
}