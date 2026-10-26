import 'package:flutter/material.dart';
import 'storage.dart';
import 'document_calculation.dart';
import 'draft_pdf.dart';
import 'package:printing/printing.dart';

void main() => runApp(const BizPilotApp());

class BizPilotApp extends StatelessWidget {
  const BizPilotApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BIZPILOT AI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF39B8FF), brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF101622)),
    home: const Dashboard(),
  );
}

class Customer {
  Customer(this.name, this.email);
  final String name;
  final String email;
}

class BusinessDocument {
  BusinessDocument(this.number, this.customer, this.description, this.amount, this.isInvoice, [List<DraftLine>? items]) : items = items ?? [DraftLine(description: description, quantity: 1, unitPriceCents: (amount * 100).round())];
  final String number;
  final String customer;
  final String description;
  final double amount;
  final bool isInvoice;
  final List<DraftLine> items;
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int selected = 0;
  final customers = <Customer>[];
  final documents = <BusinessDocument>[];
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final descriptionController = TextEditingController();
  final amountController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  int nextDraftNumber = 1;
  bool loaded = false;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final data = await LocalStorage.load();
      if (!mounted) return;
      setState(() {
        final savedNext = (data['nextDraftNumber'] as num?)?.toInt() ?? 1;
        final existing = (data['documents'] as List? ?? []).whereType<Map>()
          .map((d) => int.tryParse((d['number']?.toString() ?? '').replaceFirst('ENT-', '')) ?? 0)
          .fold<int>(0, (maxValue, n) => n > maxValue ? n : maxValue);
        nextDraftNumber = savedNext > existing ? savedNext : existing + 1;
        loaded = true;
        customers
          ..clear()
          ..addAll((data['customers'] as List? ?? []).whereType<Map>().map((e) =>
            Customer(e['name']?.toString() ?? '', e['email']?.toString() ?? '')));
        documents
          ..clear()
          ..addAll((data['documents'] as List? ?? []).whereType<Map>().map((e) =>
            BusinessDocument(
              e['number']?.toString() ?? '',
              e['customer']?.toString() ?? '',
              e['description']?.toString() ?? '',
              (e['amount'] as num?)?.toDouble() ?? 0,
              e['isInvoice'] == true,
              (e['items'] as List? ?? []).whereType<Map>().map((item) => DraftLine.fromJson(Map<String, dynamic>.from(item))).toList().isEmpty
                ? null
                : (e['items'] as List).whereType<Map>().map((item) => DraftLine.fromJson(Map<String, dynamic>.from(item))).toList(),
            )));
      });
    } catch (_) {
      if (mounted) {
        setState(() => loaded = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gespeicherte Daten konnten nicht geladen werden.')));
      }
    }
  }

  Future<void> _persist() async {
    try {
      await LocalStorage.save({
        'nextDraftNumber': nextDraftNumber,
        'customers': customers.map((e) => {'name': e.name, 'email': e.email}).toList(),
        'documents': documents.map((e) => {
          'number': e.number, 'customer': e.customer, 'description': e.description,
          'amount': e.amount, 'isInvoice': e.isInvoice,
          'items': e.items.map((line) => line.toJson()).toList(),
        }).toList(),
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speichern fehlgeschlagen.')));
    }
  }


  @override
  void dispose() {
    for (final c in [nameController, emailController, descriptionController, amountController, quantityController]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> addCustomer() async {
    nameController.clear();
    emailController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kunde hinzufügen'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: emailController, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-Mail')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Abbrechen')),
          FilledButton(onPressed: () {
            if (nameController.text.trim().isEmpty) return;
            setState(() => customers.add(Customer(nameController.text.trim(), emailController.text.trim())));
            _persist();
            Navigator.pop(dialogContext);
          }, child: const Text('Speichern')),
        ],
      ),
    );
  }

  Future<void> removeCustomer(int index) async {
    final name = customers[index].name;
    if (documents.any((d) => d.customer == name)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kunde wird in einem Entwurf verwendet und kann nicht gelöscht werden.')));
      return;
    }
    setState(() => customers.removeAt(index));
    await _persist();
  }

  Future<void> previewDocument(BusinessDocument document) async {
    try {
      await Printing.layoutPdf(
        name: '${document.number}.pdf',
        onLayout: (_) => createDraftPdf(
          document.number, document.customer, document.items, 0),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF-Vorschau konnte nicht geöffnet werden.')));
    }
  }

  Future<void> removeDocument(BusinessDocument document) async {
    setState(() => documents.remove(document));
    await _persist();
  }

  Future<void> addDocument(bool invoice) async {
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte zuerst einen Kunden anlegen.')));
      return;
    }
    descriptionController.clear();
    amountController.clear();
    quantityController.text = '1';
    var customerIndex = 0;
    final lines = <DraftLine>[];
    var discountPercent = 0;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, updateDialog) => AlertDialog(
        title: Text(invoice ? 'Rechnungsentwurf' : 'Angebotsentwurf'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            initialValue: customerIndex,
            decoration: const InputDecoration(labelText: 'Kunde'),
            items: List.generate(customers.length, (i) => DropdownMenuItem(value: i, child: Text(customers[i].name))),
            onChanged: (v) { if (v != null) updateDialog(() => customerIndex = v); },
          ),
          TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Leistung')),
          TextField(controller: quantityController, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Menge')),
          TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Einzelpreis in EUR (Entwurf)')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
              final quantity = int.tryParse(quantityController.text.trim());
              if (descriptionController.text.trim().isEmpty || amount == null ||
                  !amount.isFinite || amount < 0 || quantity == null || quantity <= 0) return;
              updateDialog(() => lines.add(DraftLine(
                description: descriptionController.text.trim(),
                quantity: quantity, unitPriceCents: (amount * 100).round())));
              descriptionController.clear();
              amountController.clear();
              quantityController.text = '1';
            },
            icon: const Icon(Icons.add),
            label: const Text('Position hinzufügen'),
          ),
          ...lines.asMap().entries.map((entry) => ListTile(
            dense: true,
            title: Text(entry.value.description),
            subtitle: Text('${entry.value.quantity} × ${DraftTotals.euro(entry.value.unitPriceCents)}'),
            trailing: IconButton(icon: const Icon(Icons.close),
              onPressed: () => updateDialog(() => lines.removeAt(entry.key))),
          )),
          DropdownButtonFormField<int>(
            initialValue: discountPercent,
            decoration: const InputDecoration(labelText: 'Rabatt auf Entwurf'),
            items: [0, 5, 10, 15, 20].map((p) => DropdownMenuItem(value: p, child: Text('$p %'))).toList(),
            onChanged: (v) { if (v != null) updateDialog(() => discountPercent = v); },
          ),
          Text('Gesamt: ${DraftTotals.euro(DraftTotals.afterDiscountCents(lines, discountPercent * 100))}'),
          const Text('Interner Entwurf ohne Steuerberechnung; keine rechtsgültige Rechnung.'),

        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Abbrechen')),
          FilledButton(onPressed: () {
            if (lines.isEmpty) return;
            final total = DraftTotals.afterDiscountCents(lines, discountPercent * 100);
            final number = 'ENT-${nextDraftNumber.toString().padLeft(4, '0')}';
            nextDraftNumber++;
            setState(() => documents.add(BusinessDocument(
              number, customers[customerIndex].name, lines.map((l) => l.description).join(', '), total / 100, invoice, List.of(lines))));
            _persist();
            Navigator.pop(dialogContext);
          }, child: const Text('Entwurf speichern')),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Übersicht', 'Kunden', 'Angebote', 'Rechnungen'];
    final shown = documents.where((d) => d.isInvoice == (selected == 3)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('BIZPILOT AI · ${titles[selected]}')),
      body: !loaded ? const Center(child: CircularProgressIndicator()) : SafeArea(child: Padding(padding: const EdgeInsets.all(16),
        child: switch (selected) {
          0 => ListView(children: [
            const Text('Dein Business im Überblick', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(child: ListTile(leading: const Icon(Icons.people), title: const Text('Kunden'),
              trailing: Text('${customers.length}'))),
            Card(child: ListTile(leading: const Icon(Icons.description), title: const Text('Angebotsentwürfe'),
              trailing: Text('${documents.where((d) => !d.isInvoice).length}'))),
            Card(child: ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Rechnungsentwürfe'),
              trailing: Text('${documents.where((d) => d.isInvoice).length}'))),
            const SizedBox(height: 12),
            const Text('Prototyp: Daten lokal gespeichert, noch nicht verschlüsselt oder synchronisiert. Keine echten Rechnungen versenden.'),
          ]),
          1 => customers.isEmpty
            ? const Center(child: Text('Noch keine Kunden. Tippe auf +.'))
            : ListView.builder(itemCount: customers.length, itemBuilder: (_, i) => Card(child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(customers[i].name), subtitle: Text(customers[i].email),
                trailing: IconButton(tooltip: 'Kunde löschen', icon: const Icon(Icons.delete_outline),
                  onPressed: () => removeCustomer(i))))),
          _ => shown.isEmpty
            ? Center(child: Text('Noch keine ${selected == 3 ? 'Rechnungs-' : 'Angebots-'}entwürfe. Tippe auf +.'))
            : ListView.builder(itemCount: shown.length, itemBuilder: (_, i) {
                final d = shown[i];
                return Card(child: ListTile(
                  title: Text('${d.number} · ${d.customer}'),
                  subtitle: Text('${d.items.length} Position(en) · ${d.description}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${d.amount.toStringAsFixed(2)} €'),
                    IconButton(tooltip: 'PDF-Vorschau', icon: const Icon(Icons.picture_as_pdf_outlined),
                      onPressed: () => previewDocument(d)),
                    IconButton(tooltip: 'Entwurf löschen', icon: const Icon(Icons.delete_outline),
                      onPressed: () => removeDocument(d)),
                  ])));
              }),
        },
      )),
      floatingActionButton: !loaded || selected == 0 ? null : FloatingActionButton(
        onPressed: selected == 1 ? addCustomer : () => addDocument(selected == 3),
        child: const Icon(Icons.add)),
      bottomNavigationBar: NavigationBar(selectedIndex: selected,
        onDestinationSelected: (index) => setState(() => selected = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Übersicht'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Kunden'),
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Angebote'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Rechnungen'),
        ]),
    );
  }
}
