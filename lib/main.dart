import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

// Un gasto: lo que se compró, cuánto costó y en qué categoría cae.
// Es una app de práctica: no se conecta a ninguna cuenta ni banco.
class Gasto {
  Gasto({required this.descripcion, required this.monto, required this.categoria});

  final String descripcion;
  final double monto;
  final String categoria;
}

const categorias = ['Comida', 'Transporte', 'Casa', 'Diversión', 'Otros'];

class GastoState extends ChangeNotifier {
  GastoState() {
    cargar();
  }

  final gastos = <Gasto>[];

  // Al abrir la app, lee los gastos guardados en el teléfono/navegador.
  Future<void> cargar() async {
    var prefs = await SharedPreferences.getInstance();
    var guardados = prefs.getStringList('gastos') ?? [];
    gastos
      ..clear()
      ..addAll(
        guardados.map((texto) {
          var json = jsonDecode(texto) as Map<String, dynamic>;
          return Gasto(
            descripcion: json['descripcion'] as String,
            monto: (json['monto'] as num).toDouble(),
            categoria: json['categoria'] as String,
          );
        }),
      );
    notifyListeners();
  }

  // Después de cada cambio, escribe la lista completa en el guardado local.
  Future<void> guardar() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'gastos',
      gastos
          .map(
            (g) => jsonEncode({
              'descripcion': g.descripcion,
              'monto': g.monto,
              'categoria': g.categoria,
            }),
          )
          .toList(),
    );
  }

  double get total => gastos.fold(0, (suma, g) => suma + g.monto);

  double totalPorCategoria(String categoria) =>
      gastos.where((g) => g.categoria == categoria).fold(0, (suma, g) => suma + g.monto);

  void agregar(Gasto gasto) {
    gastos.add(gasto);
    guardar();
    notifyListeners();
  }

  void quitar(Gasto gasto) {
    gastos.remove(gasto);
    guardar();
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GastoState(),
      child: MaterialApp(
        title: 'Gastos',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = const ListaPage();
      case 1:
        page = const AgregarPage();
      default:
        throw UnimplementedError('No hay página para $selectedIndex');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 600,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.list),
                      label: Text('Gastos'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.add),
                      label: Text('Agregar'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ListaPage extends StatelessWidget {
  const ListaPage({super.key});

  @override
  Widget build(BuildContext context) {
    var state = context.watch<GastoState>();

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Total gastado'),
                      Text(
                        '\$${state.total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'App de práctica: tus gastos se guardan en este dispositivo y ya no se borran al cerrar.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Por categoría'),
              const SizedBox(height: 8),
              for (var categoria in categorias)
                if (state.totalPorCategoria(categoria) > 0)
                  ListTile(
                    title: Text(categoria),
                    trailing: Text(
                      '\$${state.totalPorCategoria(categoria).toStringAsFixed(2)}',
                    ),
                  ),
              const SizedBox(height: 16),
              if (state.gastos.isEmpty)
                const Text('Sin gastos todavía. Agrega el primero en la pestaña Agregar.')
              else
                for (var gasto in state.gastos)
                  ListTile(
                    leading: const Icon(Icons.receipt),
                    title: Text(gasto.descripcion),
                    subtitle: Text(gasto.categoria),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('\$${gasto.monto.toStringAsFixed(2)}'),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => state.quitar(gasto),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class AgregarPage extends StatefulWidget {
  const AgregarPage({super.key});

  @override
  State<AgregarPage> createState() => _AgregarPageState();
}

class _AgregarPageState extends State<AgregarPage> {
  final descripcionController = TextEditingController();
  final montoController = TextEditingController();
  var categoria = categorias.first;
  var error = '';

  @override
  void dispose() {
    descripcionController.dispose();
    montoController.dispose();
    super.dispose();
  }

  void guardar() {
    var monto = double.tryParse(montoController.text.replaceAll(',', '.'));
    if (descripcionController.text.trim().isEmpty || monto == null || monto <= 0) {
      setState(() {
        error = 'Escribe qué compraste y un monto mayor a 0.';
      });
      return;
    }
    context.read<GastoState>().agregar(
      Gasto(
        descripcion: descripcionController.text.trim(),
        monto: monto,
        categoria: categoria,
      ),
    );
    descripcionController.clear();
    montoController.clear();
    setState(() {
      error = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gasto agregado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Agregar gasto'),
            const SizedBox(height: 16),
            TextField(
              controller: descripcionController,
              decoration: const InputDecoration(
                labelText: '¿Qué compraste?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: categoria,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var c in categorias)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    categoria = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: guardar,
              icon: const Icon(Icons.check),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
