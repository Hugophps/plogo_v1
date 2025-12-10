import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sessions/booking_payment_repository.dart';
import '../sessions/models/booking_payment.dart';

class ProfileSessionsPage extends StatefulWidget {
  const ProfileSessionsPage({super.key});

  @override
  State<ProfileSessionsPage> createState() => _ProfileSessionsPageState();
}

class _ProfileSessionsPageState extends State<ProfileSessionsPage>
    with SingleTickerProviderStateMixin {
  final BookingPaymentRepository _repository = const BookingPaymentRepository();
  late final TabController _tabController;
  BookingPaymentRole _currentRole = BookingPaymentRole.driver;
  final Map<BookingPaymentRole, _BookingPaymentsState> _states = {
    BookingPaymentRole.driver: _BookingPaymentsState(),
    BookingPaymentRole.owner: _BookingPaymentsState(),
  };
  final Set<String> _pendingSlots = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final role =
          _tabController.index == 0 ? BookingPaymentRole.driver : BookingPaymentRole.owner;
      _switchRole(role);
    });
    _fetchRole(BookingPaymentRole.driver, force: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchRole(BookingPaymentRole role) {
    setState(() => _currentRole = role);
    final state = _states[role]!;
    if (!state.loadedOnce && !state.isLoading) {
      _fetchRole(role, force: true);
    }
  }

  Future<void> _fetchRole(BookingPaymentRole role, {bool force = false}) async {
    final state = _states[role]!;
    if (state.isLoading) return;
    if (!force && state.loadedOnce) return;
    setState(() {
      state.isLoading = true;
      state.error = null;
      if (!force) _currentRole = role;
    });
    try {
      final items = await _repository.fetchPayments(role);
      if (!mounted) return;
      setState(() {
        state.items = items;
        state.loadedOnce = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        state.error = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        state.isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Sessions de charges'),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF2C75FF),
          labelColor: Colors.black87,
          tabs: const [
            Tab(text: 'Conducteur'),
            Tab(text: 'Propriétaire'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildRoleView(BookingPaymentRole.driver),
          _buildRoleView(BookingPaymentRole.owner),
        ],
      ),
    );
  }

  Widget _buildRoleView(BookingPaymentRole role) {
    final state = _states[role]!;
    return RefreshIndicator.adaptive(
      onRefresh: () => _fetchRole(role, force: true),
      child: _buildRoleContent(role, state),
    );
  }

  Widget _buildRoleContent(BookingPaymentRole role, _BookingPaymentsState state) {
    if (state.isLoading && !state.loadedOnce) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (state.error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _ErrorCard(
            message: state.error!,
            onRetry: () => _fetchRole(role, force: true),
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      final emptyText = role == BookingPaymentRole.driver
          ? 'Aucune session réservée pour le moment.'
          : 'Aucune session sur vos bornes pour l’instant.';
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Icon(Icons.ev_station, size: 64, color: Color(0xFF2C75FF)),
                const SizedBox(height: 12),
                Text(
                  emptyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final payment = state.items[index];
        final slotKey = payment.slotId ?? '';
        return _PaymentCard(
          payment: payment,
          isPending: slotKey.isNotEmpty && _pendingSlots.contains(slotKey),
          onCopy: () => _copyReference(payment.paymentReference),
          onDriverAction: payment.role == BookingPaymentRole.driver
              ? (BookingPaymentDriverAction action) =>
                  _handleDriverAction(payment, action)
              : null,
          onOwnerAction: payment.role == BookingPaymentRole.owner
              ? (BookingPaymentOwnerAction action) =>
                  _handleOwnerAction(payment, action)
              : null,
        );
      },
    );
  }

  Future<void> _handleDriverAction(
    BookingPayment payment,
    BookingPaymentDriverAction action,
  ) async {
    final slotId = payment.slotId;
    if (slotId == null) return;
    setState(() => _pendingSlots.add(slotId));
    try {
      final updated = await _repository.updateDriverPayment(slotId, action);
      if (!mounted) return;
      _applyUpdatedPayment(updated);
      _showSnack(
        action == BookingPaymentDriverAction.cancelMark
            ? 'Signalement annulé.'
            : 'Paiement indiqué au propriétaire.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(error.toString(), isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _pendingSlots.remove(slotId));
    }
  }

  Future<void> _handleOwnerAction(
    BookingPayment payment,
    BookingPaymentOwnerAction action,
  ) async {
    final slotId = payment.slotId;
    if (slotId == null) return;
    setState(() => _pendingSlots.add(slotId));
    try {
      final updated = await _repository.updateOwnerPayment(slotId, action);
      if (!mounted) return;
      _applyUpdatedPayment(updated);
      _showSnack(
        action == BookingPaymentOwnerAction.revert
            ? 'Validation annulée.'
            : 'Paiement confirmé.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(error.toString(), isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _pendingSlots.remove(slotId));
    }
  }

  void _applyUpdatedPayment(BookingPayment updated) {
    setState(() {
      for (final role in BookingPaymentRole.values) {
        final state = _states[role]!;
        final index = state.items.indexWhere((item) => item.slotId == updated.slotId);
        if (index == -1) continue;
        final list = state.items.toList();
        list[index] = role == updated.role ? updated : updated.copyForRole(role);
        state.items = list;
      }
    });
  }

  Future<void> _copyReference(String reference) async {
    await Clipboard.setData(ClipboardData(text: reference));
    if (!mounted) return;
    _showSnack('Référence copiée.');
  }

  void _showSnack(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF2C75FF),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.isPending,
    required this.onCopy,
    this.onDriverAction,
    this.onOwnerAction,
  });

  final BookingPayment payment;
  final bool isPending;
  final VoidCallback onCopy;
  final ValueChanged<BookingPaymentDriverAction>? onDriverAction;
  final ValueChanged<BookingPaymentOwnerAction>? onOwnerAction;

  @override
  Widget build(BuildContext context) {
    final statusLabel = payment.statusLabel(payment.role);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.station.name ?? 'Station',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        payment.station.addressLine,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        payment.slot.rangeLabel,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      if (payment.role == BookingPaymentRole.owner &&
                          payment.driver != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7ECFF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 18,
                                  color: Color(0xFF2C75FF),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  payment.driver!.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                _StatusChip(label: statusLabel),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Énergie',
                    value: payment.energyLabel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: 'Montant',
                    value: payment.amountLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ReferenceRow(reference: payment.paymentReference, onCopy: onCopy),
            if (payment.noChargeCompleted)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Aucune charge enregistrée sur ce créneau.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            const SizedBox(height: 12),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (onDriverAction != null) {
      if (payment.canDriverMark) {
        return FilledButton(
          onPressed: isPending
              ? null
              : () => onDriverAction!(BookingPaymentDriverAction.markAsPaid),
          child: isPending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Paiement effectué'),
        );
      }
      if (payment.canDriverCancel) {
        return OutlinedButton(
          onPressed: isPending
              ? null
              : () => onDriverAction!(BookingPaymentDriverAction.cancelMark),
          child: isPending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Annuler la déclaration'),
        );
      }
    }

    if (onOwnerAction != null) {
      if (payment.canOwnerConfirm) {
        return FilledButton(
          onPressed: isPending
              ? null
              : () => onOwnerAction!(BookingPaymentOwnerAction.confirm),
          child: isPending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Paiement reçu'),
        );
      }
      if (payment.canOwnerRevert) {
        return OutlinedButton(
          onPressed: isPending
              ? null
              : () => onOwnerAction!(BookingPaymentOwnerAction.revert),
          child: isPending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Annuler la validation'),
        );
      }
    }

    return const SizedBox.shrink();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7ECFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2C75FF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({required this.reference, required this.onCopy});

  final String reference;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Référence virement',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  reference,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
            color: const Color(0xFF2C75FF),
            tooltip: 'Copier',
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Erreur',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _BookingPaymentsState {
  List<BookingPayment> items = const [];
  bool isLoading = false;
  bool loadedOnce = false;
  String? error;
}
