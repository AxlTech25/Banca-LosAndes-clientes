import 'package:flutter/material.dart';



import '../../../core/router/app_routes.dart';

import '../../../core/theme/app_colors.dart';

import '../../viewmodels/credits_view_model.dart';

import '../../viewmodels/dashboard_view_model.dart';

import '../../viewmodels/notificaciones_view_model.dart';

import '../../viewmodels/profile_view_model.dart';

import '../../viewmodels/request_credit_view_model.dart';

import '../../widgets/app_bottom_nav.dart';
import '../../widgets/banco_los_andes_logo.dart';

import '../cuenta/cuenta_screen.dart';
import '../credits/credit_detail_screen.dart';
import '../credits/pago_credito_flow.dart';

import '../credits/credits_tab.dart';

import '../home/home_tab.dart';

import '../notifications/notificaciones_screen.dart';

import '../profile/profile_tab.dart';

import '../request/request_tab.dart';



class MainShellScreen extends StatefulWidget {

  const MainShellScreen({super.key});



  @override

  State<MainShellScreen> createState() => _MainShellScreenState();

}



class _MainShellScreenState extends State<MainShellScreen> {

  int _tabIndex = 0;



  final _dashboardViewModel = DashboardViewModel();

  final _creditsViewModel = CreditsViewModel();

  final _requestViewModel = RequestCreditViewModel();

  final _profileViewModel = ProfileViewModel();

  final _notificacionesViewModel = NotificacionesViewModel();



  static const _titles = [

    'Banco Los Andes',

    'Mis Creditos',

    'Solicitar Credito',

    'Mi Perfil',

  ];



  @override

  void initState() {

    super.initState();

    _dashboardViewModel.loadDashboard();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (!mounted) return;

      _dashboardViewModel.startListening();

      _creditsViewModel.startListening();

      _requestViewModel.startListening();

      _notificacionesViewModel.startListening();

      _notificacionesViewModel.refreshBadge();

    });

  }



  @override

  void dispose() {

    _dashboardViewModel.dispose();

    _creditsViewModel.dispose();

    _requestViewModel.dispose();

    _profileViewModel.dispose();

    _notificacionesViewModel.dispose();

    super.dispose();

  }



  Future<void> _refreshAll() async {

    await _dashboardViewModel.loadDashboard();

    await _notificacionesViewModel.refreshBadge();

    switch (_tabIndex) {

      case 1:

        await _creditsViewModel.loadCreditos();

      case 2:

        await _requestViewModel.load();

      case 3:

        await _profileViewModel.loadProfile();

      default:

        break;

    }

  }



  Future<void> _logout() async {

    await _dashboardViewModel.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);

  }



  Future<void> _openNotificaciones() async {

    await Navigator.of(context).push(

      MaterialPageRoute(

        builder: (_) =>

            NotificacionesScreen(viewModel: _notificacionesViewModel),

      ),

    );

    await _notificacionesViewModel.refreshBadge();

  }



  void _onTabChanged(int index) {

    setState(() => _tabIndex = index);

    switch (index) {

      case 1:

        _creditsViewModel.loadCreditos();

      case 2:

        _requestViewModel.load();

      case 3:

        _profileViewModel.loadProfile();

      default:

        break;

    }

  }



  Future<void> _openCuentaFromHome() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CuentaScreen()),
    );
    await _dashboardViewModel.loadDashboard();
    await _profileViewModel.loadProfile();
  }

  Future<void> _pagarCuotaFromHome() async {
    final creditoId = _dashboardViewModel.creditoActivoId;
    if (creditoId == null || !_dashboardViewModel.canPagarCuota) return;

    final ok = await ejecutarPagoCuota(
      context,
      viewModel: _creditsViewModel,
      creditoId: creditoId,
      monto: _dashboardViewModel.cuotaPagoMonto,
      onComplete: () async {
        await _creditsViewModel.refreshCreditos();
        await _dashboardViewModel.loadDashboard();
      },
    );

    if (ok && mounted) {
      await _creditsViewModel.refreshCreditos();
      await _dashboardViewModel.loadDashboard();
    }
  }

  Future<void> _openCreditoFromHome(String creditoId) async {

    _onTabChanged(1);

    await Navigator.of(context).push(

      MaterialPageRoute(

        builder: (_) => CreditDetailScreen(

          creditoId: creditoId,

          creditsViewModel: _creditsViewModel,

          onPaymentComplete: _dashboardViewModel.loadDashboard,

        ),

      ),

    );

    await _creditsViewModel.loadCreditos();

    await _dashboardViewModel.loadDashboard();

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        automaticallyImplyLeading: false,

        toolbarHeight: 64,

        backgroundColor: AppColors.surface,

        elevation: 1,

        title: _tabIndex == 0
            ? const BancoLosAndesLogo(
                height: 40,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              )
            : Text(
                _titles[_tabIndex],
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
        centerTitle: true,

        actions: [

          AnimatedBuilder(

            animation: _notificacionesViewModel,

            builder: (context, _) {

              return IconButton(

                tooltip: 'Notificaciones',

                onPressed: _openNotificaciones,

                icon: Badge(

                  isLabelVisible: _notificacionesViewModel.noLeidas > 0,

                  label: Text('${_notificacionesViewModel.noLeidas}'),

                  child: const Icon(

                    Icons.notifications_outlined,

                    color: AppColors.primary,

                  ),

                ),

              );

            },

          ),

          IconButton(

            tooltip: 'Actualizar',

            onPressed: _refreshAll,

            icon: const Icon(Icons.refresh, color: AppColors.primary),

          ),

          IconButton(

            tooltip: 'Cerrar sesion',

            onPressed: _logout,

            icon: const Icon(Icons.logout, color: AppColors.primary),

          ),

        ],

      ),

      body: SafeArea(

        top: false,

        child: IndexedStack(

          index: _tabIndex,

          children: [

            AnimatedBuilder(

              animation: _dashboardViewModel,

              builder: (context, _) {

                return HomeTab(

                  viewModel: _dashboardViewModel,

                  onNavigateToTab: _onTabChanged,

                  onOpenCredito: _openCreditoFromHome,

                  onOpenCuenta: _openCuentaFromHome,

                  onPagarCuota: _pagarCuotaFromHome,

                );

              },

            ),

            CreditsTab(

              viewModel: _creditsViewModel,

              onDataChanged: _dashboardViewModel.loadDashboard,

            ),

            RequestTab(viewModel: _requestViewModel),

            ProfileTab(viewModel: _profileViewModel),

          ],

        ),

      ),

      bottomNavigationBar: AppBottomNav(

        currentIndex: _tabIndex,

        onTap: _onTabChanged,

      ),

    );

  }

}


