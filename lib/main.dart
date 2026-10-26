import 'package:flutter/material.dart';

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
  BusinessDocument(this.number, this.customer, this.description, this.amount, this.isInvoice);
  final String number;
  final String customer;
  final String description;
  final double amount;
  final bool isInvoice;
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

  @override
  void dispose() {
    for (final c in [nameController, emailController, descriptionController, amountController]) {
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
            Navigator.pop(dialogContext);
          }, child: const Text('Speichern')),
        ],
      ),
    );
  }

  Future<void> addDocument(bool invoice) async {
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte zuerst einen Kunden anlegen.')));
      return;
    }
    descriptionController.clear();
    amountController.clear();
    var customer = customers.first.name;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, updateDialog) => AlertDialog(
        title: Text(invoice ? 'Rechnungsentwurf' : 'Angebotsentwurf'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: customer,
            decoration: const InputDecoration(labelText: 'Kunde'),
            items: customers.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
            onChanged: (v) { if (v != null) updateDialog(() => customer = v); },
          ),
          TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Leistung')),
          TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Betrag in EUR (Entwurf)')),
          const SizedBox(height: 12),
          const Text('Nur interner Entwurf: keine Steuerberechnung, keine rechtssichere Rechnung.'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Abbrechen')),
          FilledButton(onPressed: () {
            final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
            if (descriptionController.text.trim().isEmpty || amount == null || !amount.isFinite || amount < 0) return;
            final number = 'ENT-${(documents.length + 1).toString().padLeft(4, '0')}';
            setState(() => documents.add(BusinessDocument(
              number, customer, descriptionController.text.trim(), amount, invoice)));
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
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(16),
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
            const Text('Prototyp: Daten bleiben nur bis zum Schließen der App erhalten. Keine echten Rechnungen versenden.'),
          ]),
          1 => customers.isEmpty
            ? const Center(child: Text('Noch keine Kunden. Tippe auf +.'))
            : ListView.builder(itemCount: customers.length, itemBuilder: (_, i) => Card(child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(customers[i].name), subtitle: Text(customers[i].email)))),
          _ => shown.isEmpty
            ? Center(child: Text('Noch keine ${selected == 3 ? 'Rechnungs-' : 'Angebots-'}entwürfe. Tippe auf +.'))
            : ListView.builder(itemCount: shown.length, itemBuilder: (_, i) {
                final d = shown[i];
                return Card(child: ListTile(
                  title: Text('${d.number} · ${d.customer}'),
                  subtitle: Text(d.description),
                  trailing: Text('${d.amount.toStringAsFixed(2)} €')));
              }),
        },
      )),
      floatingActionButton: selected == 0 ? null : FloatingActionButton(
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
