import 'package:flutter/material.dart';

void main() => runApp(const BizPilotApp());

class BizPilotApp extends StatelessWidget {
  const BizPilotApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BIZPILOT AI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF39B8FF), brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF101622),
    ),
    home: const Dashboard(),
  );
}

class Customer {
  Customer(this.name, this.email);
  final String name;
  final String email;
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int selected = 0;
  final customers = <Customer>[];
  final nameController = TextEditingController();
  final emailController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
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
          TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-Mail')),
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

  @override
  Widget build(BuildContext context) {
    final titles = ['Übersicht', 'Kunden', 'Angebote', 'Rechnungen'];
    return Scaffold(
      appBar: AppBar(title: Text('BIZPILOT AI · ${titles[selected]}')),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (selected) {
          0 => ListView(children: [
            const Text('Dein Business im Überblick', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(child: ListTile(leading: const Icon(Icons.people), title: const Text('Kunden'), trailing: Text('${customers.length}'))),
            const Card(child: ListTile(leading: Icon(Icons.description), title: Text('Angebote'), subtitle: Text('Wird in der nächsten Ausbaustufe aktiviert'))),
            const Card(child: ListTile(leading: Icon(Icons.receipt_long), title: Text('Rechnungen'), subtitle: Text('Wird in der nächsten Ausbaustufe aktiviert'))),
            const SizedBox(height: 12),
            const Text('Vorschauversion: Kundendaten werden derzeit nur im Arbeitsspeicher gehalten.'),
          ]),
          1 => customers.isEmpty
            ? const Center(child: Text('Noch keine Kunden. Tippe auf +.'))
            : ListView.builder(itemCount: customers.length, itemBuilder: (_, i) => Card(child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(customers[i].name),
                subtitle: Text(customers[i].email),
              ))),
          2 => const Center(child: Text('Angebotsverwaltung folgt.')),
          _ => const Center(child: Text('Rechnungsverwaltung folgt.')),
        },
      )),
      floatingActionButton: selected == 1 ? FloatingActionButton(onPressed: addCustomer, child: const Icon(Icons.add)) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) => setState(() => selected = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Übersicht'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Kunden'),
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Angebote'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Rechnungen'),
        ],
      ),
    );
  }
}
