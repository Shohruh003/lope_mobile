import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/lopepay_repository.dart';

/// Create or edit a LopePay installment plan. Mirrors the web's
/// `ShopCustomerForm.tsx` — customer name/phone, product (pick from list
/// or type free-form), money math (totalPrice / monthsTotal /
/// monthlyPayment), start date, optional notes/serial.
class LopepayCustomerFormScreen extends ConsumerStatefulWidget {
  const LopepayCustomerFormScreen({super.key, this.installmentId});

  /// When set, the form loads existing installment data and PATCHes on
  /// save. When null, the form POSTs to create a new installment.
  final String? installmentId;

  @override
  ConsumerState<LopepayCustomerFormScreen> createState() =>
      _LopepayCustomerFormScreenState();
}

class _LopepayCustomerFormScreenState
    extends ConsumerState<LopepayCustomerFormScreen> {
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController(text: '+998');
  final _productName = TextEditingController();
  final _productSerial = TextEditingController();
  final _totalPrice = TextEditingController();
  final _monthsTotal = TextEditingController();
  final _monthlyPayment = TextEditingController();
  final _notes = TextEditingController();
  String? _productId;
  DateTime _startDate = DateTime.now();

  List<LopepayProduct> _products = const [];
  bool _loadingProducts = true;
  bool _loadingExisting = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.installmentId != null;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    if (_isEdit) _seedFromExisting();

    // Auto-compute monthly when total + months are set and monthly is empty.
    void recompute() {
      if (_monthlyPayment.text.isNotEmpty) return;
      final total = int.tryParse(_totalPrice.text);
      final months = int.tryParse(_monthsTotal.text);
      if (total != null && months != null && total > 0 && months > 0) {
        _monthlyPayment.text = ((total + months - 1) ~/ months).toString();
      }
    }

    _totalPrice.addListener(recompute);
    _monthsTotal.addListener(recompute);
  }

  Future<void> _fetchProducts() async {
    try {
      final list = await ref.read(lopepayRepositoryProvider).products();
      if (!mounted) return;
      setState(() {
        _products = list;
        _loadingProducts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> _seedFromExisting() async {
    setState(() => _loadingExisting = true);
    try {
      final m = await ref
          .read(lopepayRepositoryProvider)
          .getInstallment(widget.installmentId!);
      _customerName.text = (m['customerName'] ?? '').toString();
      _customerPhone.text = (m['customerPhone'] ?? '+998').toString();
      _productName.text = (m['productName'] ?? '').toString();
      _productSerial.text = (m['productSerial'] ?? '').toString();
      _productId = m['productId']?.toString();
      _totalPrice.text = ((m['totalPrice'] ?? 0) as num).toInt().toString();
      _monthsTotal.text = ((m['monthsTotal'] ?? 0) as num).toInt().toString();
      _monthlyPayment.text =
          ((m['monthlyPayment'] ?? 0) as num).toInt().toString();
      _notes.text = (m['notes'] ?? '').toString();
      final start = m['startDate']?.toString();
      if (start != null && start.isNotEmpty) {
        final parsed = DateTime.tryParse(start);
        if (parsed != null) _startDate = parsed;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = tr(ref, 'common.error', 'Xatolik'));
      }
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _productName.dispose();
    _productSerial.dispose();
    _totalPrice.dispose();
    _monthsTotal.dispose();
    _monthlyPayment.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _addNewProduct() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 18,
          bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                tr(ref, 'mobile.lopepay.products.newProduct', "Yangi mahsulot"),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                    hintText: tr(ref, 'mobile.lopepay.products.namePh', "Nomi"))),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                  hintText: tr(ref, 'mobile.lopepay.customerForm.defaultPrice',
                      "Standart narx (ixtiyoriy)")),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                child: Text(tr(ref, 'common.save', "Saqlash")),
              ),
            ),
          ],
        ),
      ),
    );
    try {
      if (ok != true) return;
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      final price = int.tryParse(priceCtrl.text.trim());
      final created = await ref
          .read(lopepayRepositoryProvider)
          .createProduct(name: name, defaultPrice: price);
      setState(() {
        _products = [..._products, created];
        _productId = created.id;
        _productName.text = created.name;
        if (created.price > 0 && _totalPrice.text.isEmpty) {
          _totalPrice.text = created.price.toString();
        }
      });
      ref.invalidate(lopepayProductsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    } finally {
      nameCtrl.dispose();
      priceCtrl.dispose();
    }
  }

  Future<void> _submit() async {
    final name = _customerName.text.trim();
    final phone = _customerPhone.text.trim();
    final productName = _productName.text.trim();
    final total = int.tryParse(_totalPrice.text.trim()) ?? 0;
    final months = int.tryParse(_monthsTotal.text.trim()) ?? 0;
    final monthly = int.tryParse(_monthlyPayment.text.trim()) ?? 0;

    if (name.isEmpty || phone.length < 4 || productName.isEmpty ||
        total <= 0 || months <= 0 || monthly <= 0) {
      setState(() => _error = tr(ref, 'mobile.lopepay.customerForm.fillRequired',
          "Iltimos, barcha majburiy maydonlarni to'ldiring"));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        if (_productId != null && _productId!.isNotEmpty) 'productId': _productId,
        'productName': productName,
        if (_productSerial.text.trim().isNotEmpty)
          'productSerial': _productSerial.text.trim(),
        'customerName': name,
        'customerPhone': phone,
        'totalPrice': total,
        'monthlyPayment': monthly,
        'monthsTotal': months,
        'startDate':
            '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      };
      final repo = ref.read(lopepayRepositoryProvider);
      if (_isEdit) {
        await repo.updateInstallment(widget.installmentId!, body);
      } else {
        await repo.createInstallment(body);
      }
      ref.invalidate(lopepayCustomersProvider);
      ref.invalidate(lopepayDashboardProvider);
      if (!mounted) return;
      // The customer detail screen keys on customerPhone (we group by
      // phone — there's no per-customer endpoint on the backend), so
      // route there using the form's phone, not the installment id.
      if (phone.isNotEmpty) {
        context.go('/lopepay/customers/${Uri.encodeComponent(phone)}');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = "${tr(ref, 'common.error', 'Xatolik')}: $e");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit
            ? tr(ref, 'mobile.lopepay.customerForm.editTitle', "Tahrirlash")
            : tr(ref, 'mobile.lopepay.customerForm.newTitle',
                "Yangi rassrochka")),
      ),
      body: _loadingExisting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _Label(tr(ref, 'lopePay.shop.customerName', "Mijoz ismi")),
                const SizedBox(height: 6),
                TextField(
                  controller: _customerName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Shohruh Azimov'),
                ),
                const SizedBox(height: 14),
                _Label(tr(ref, 'auth.phone', "Telefon")),
                const SizedBox(height: 6),
                TextField(
                  controller: _customerPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '+998 90 123 45 67'),
                ),
                const SizedBox(height: 18),
                _Label(tr(ref, 'mobile.lopepay.customerForm.product', "Mahsulot")),
                const SizedBox(height: 6),
                _ProductPicker(
                  loading: _loadingProducts,
                  products: _products,
                  selectedId: _productId,
                  onPick: (p) => setState(() {
                    _productId = p.id;
                    _productName.text = p.name;
                    if (p.price > 0 && _totalPrice.text.isEmpty) {
                      _totalPrice.text = p.price.toString();
                    }
                  }),
                  onAddNew: _addNewProduct,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _productName,
                  decoration: InputDecoration(
                      hintText: tr(ref, 'mobile.lopepay.customerForm.productName',
                          "Mahsulot nomi (masalan: iPhone 13)")),
                  onChanged: (_) {
                    if (_productId != null) {
                      setState(() => _productId = null);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _productSerial,
                  decoration: InputDecoration(
                      hintText: tr(ref, 'mobile.lopepay.customerForm.serialPh',
                          "IMEI / Serial (ixtiyoriy)")),
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: _MoneyField(
                      label: tr(ref, 'mobile.lopepay.customerForm.totalPrice',
                          "Umumiy narx"),
                      ctrl: _totalPrice,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MoneyField(
                      label: tr(ref, 'mobile.lopepay.customerForm.monthsTotal',
                          "Oylar"),
                      ctrl: _monthsTotal,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                _MoneyField(
                  label: tr(ref, 'mobile.lopepay.customerForm.monthlyPayment',
                      "Oylik to'lov"),
                  ctrl: _monthlyPayment,
                ),
                const SizedBox(height: 14),
                _Label(tr(ref, 'mobile.lopepay.customerForm.startDate',
                    "Boshlanish sanasi")),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: AppColors.textBright, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                _Label(tr(ref, 'mobile.lopepay.customerForm.notes',
                    "Eslatma (ixtiyoriy)")),
                const SizedBox(height: 6),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(tr(ref, 'common.save', "Saqlash"),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    onPressed: _saving ? null : _submit,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600));
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({required this.label, required this.ctrl});
  final String label;
  final TextEditingController ctrl;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({
    required this.loading,
    required this.products,
    required this.selectedId,
    required this.onPick,
    required this.onAddNew,
  });
  final bool loading;
  final List<LopepayProduct> products;
  final String? selectedId;
  final ValueChanged<LopepayProduct> onPick;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 36,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...products.map((p) => ChoiceChip(
              label: Text(p.name,
                  style: const TextStyle(fontSize: 12)),
              selected: selectedId == p.id,
              onSelected: (_) => onPick(p),
            )),
        ActionChip(
          avatar: const Icon(Icons.add, size: 14, color: AppColors.primary),
          label: Consumer(
            builder: (context, ref, _) => Text(
              tr(ref, 'mobile.lopepay.customerForm.addNewProduct',
                  "Yangi qo'shish"),
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ),
          onPressed: onAddNew,
        ),
      ],
    );
  }
}
