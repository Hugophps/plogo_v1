import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sessions/booking_payment_repository.dart';
import '../sessions/models/booking_payment.dart';

class ProfileSessionsPage extends StatefulWidget {
  const ProfileSessionsPage({super.key, required this.role});

  final BookingPaymentRole role;

  @override
  State<ProfileSessionsPage> createState() => _ProfileSessionsPageState();
}

class _ProfileSessionsPageState extends State<ProfileSessionsPage> {
  final BookingPaymentRepository _repository = const BookingPaymentRepository();
  final _BookingPaymentsState _state = _BookingPaymentsState();
  final Set<String> _pendingSlots = <String>{};
  late BookingPaymentRole _role;

  @override
  void initState() {
    super.initState();
    _role = widget.role;
    _fetchPayments(force: true);
  }

  Future<void> _fetchPayments({bool force = false}) async {
    if (_state.isLoading) return;
    if (!force && _state.loadedOnce) return;

    setState(() {
      _state.isLoading = true;
      _state.error = null;
    });

    try {
      final items = await _repository.fetchPayments(_role);
      if (!mounted) return;
      setState(() {
        _state.allItems = items;
        _state.loadedOnce = true;
      });
      _applyFilters();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state.error = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _state.isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Sessions de charges'),
        actions: [
          IconButton(
            tooltip: 'Filtres',
            onPressed: () {
              setState(() {
                _state.showFilters = !_state.showFilters;
              });
            },
            icon: Icon(
              _state.hasActiveFilter
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
            ),
            color: _state.showFilters || _state.hasActiveFilter
                ? const Color(0xFF2C75FF)
                : null,
          ),
        ],
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () => _fetchPayments(force: true),
        child: _buildRoleContent(_role, _state),
      ),
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
            onRetry: () => _fetchPayments(force: true),
          ),
        ],
      );
    }

    final payments = state.items;
    final showEmptyState = payments.isEmpty;
    final filterCount = state.showFilters ? 1 : 0;
    final emptyExtra = showEmptyState ? 1 : 0;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: payments.length + filterCount + emptyExtra,
      itemBuilder: (context, index) {
        if (filterCount == 1 && index == 0) {
          return _buildFilterHeader(role);
        }

        if (showEmptyState && index == filterCount) {
          return _buildEmptyState(role);
        }

        final paymentIndex = index - filterCount;
        final payment = payments[paymentIndex];
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
    bool replaced = false;

    List<BookingPayment> _replace(List<BookingPayment> source) {
      return source.map((item) {
        if (item.slotId == updated.slotId) {
          replaced = true;
          return updated;
        }
        return item;
      }).toList();
    }

    setState(() {
      _state.allItems = _replace(_state.allItems);
      if (!replaced) {
        // Nothing to update, bail out early.
        return;
      }
    });

    if (replaced) {
      _applyFilters();
    }
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

  Future<void> _pickFromDate() async {
    final initial = _state.fromDate;
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365 * 2));
    final lastDate = now.add(const Duration(days: 365));
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (selected != null) {
      setState(() {
        _state.fromDate = DateTime(selected.year, selected.month, selected.day);
      });
      _applyFilters();
    }
  }

  void _resetFromDate() {
    setState(() {
      _state.fromDate = _defaultFromDate();
    });
    _applyFilters();
  }

  void _applyFilters({bool rebuild = true}) {
    final from = DateTime(
      _state.fromDate.year,
      _state.fromDate.month,
      _state.fromDate.day,
    );
    final filtered = _state.allItems.where((payment) {
      final start = payment.slot.startAt;
      if (start.isBefore(from)) return false;
      final selectedStatus = _state.statusFilter;
      if (selectedStatus != null && payment.status != selectedStatus) {
        return false;
      }
      return true;
    }).toList();

    if (rebuild) {
      if (!mounted) return;
      setState(() {
        _state.items = filtered;
      });
    } else {
      _state.items = filtered;
    }
  }

  Widget _buildFilterHeader(BookingPaymentRole role) {
    if (!_state.showFilters) {
      return const SizedBox.shrink();
    }

    final dateText = _formatDate(_state.fromDate);
    final showReset = !_isDefaultFromDate(_state.fromDate);
    final hasStatusFilter = _state.statusFilter != null;
    final subtitle = role == BookingPaymentRole.driver
        ? "Affiche vos sessions réservées depuis cette date."
        : "Affiche les sessions de vos membres depuis cette date.";
    final statusItems = <DropdownMenuItem<BookingPaymentStatus?>>[
      const DropdownMenuItem(
        value: null,
        child: Text('Tous les statuts'),
      ),
      ...BookingPaymentStatus.values.map(
        (status) => DropdownMenuItem(
          value: status,
          child: Text(_statusFilterLabel(status, role)),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtrer par date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('Depuis le $dateText'),
                  ),
                ),
                if (showReset)
                  TextButton(
                    onPressed: _resetFromDate,
                    child: const Text('Réinitialiser'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BookingPaymentStatus?>(
              value: _state.statusFilter,
              decoration: const InputDecoration(
                labelText: 'Statut',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: statusItems,
              onChanged: (value) {
                setState(() => _state.statusFilter = value);
                _applyFilters();
              },
            ),
            if (hasStatusFilter)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() => _state.statusFilter = null);
                    _applyFilters();
                  },
                  child: const Text('Effacer le statut'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BookingPaymentRole role) {
    final emptyText = role == BookingPaymentRole.driver
        ? 'Aucune session réservée depuis cette date.'
        : 'Aucune session sur vos bornes depuis cette date.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
    );
  }

  bool _isDefaultFromDate(DateTime date) => _isDefaultDateStatic(date);

  String _formatDate(DateTime date) {
    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _statusFilterLabel(
      BookingPaymentStatus status, BookingPaymentRole role) {
    switch (status) {
      case BookingPaymentStatus.upcoming:
        return 'À venir';
      case BookingPaymentStatus.inProgress:
        return 'En cours';
      case BookingPaymentStatus.toPay:
        return role == BookingPaymentRole.driver
            ? 'À payer'
            : 'En attente de paiement';
      case BookingPaymentStatus.driverMarked:
        return role == BookingPaymentRole.driver
            ? 'Paiement indiqué'
            : 'Paiement signalé';
      case BookingPaymentStatus.paid:
        return 'Paiement reçu';
    }
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
  List<BookingPayment> allItems = const [];
  List<BookingPayment> items = const [];
  bool isLoading = false;
  bool loadedOnce = false;
  String? error;
  DateTime fromDate = _defaultFromDate();
  BookingPaymentStatus? statusFilter;
  bool showFilters = false;

  bool get hasActiveFilter =>
      !_isDefaultDateStatic(fromDate) || statusFilter != null;
}

bool _isDefaultDateStatic(DateTime date) {
  final defaultDate = _defaultFromDate();
  return date.year == defaultDate.year &&
      date.month == defaultDate.month &&
      date.day == defaultDate.day;
}

DateTime _defaultFromDate() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 30));
}
