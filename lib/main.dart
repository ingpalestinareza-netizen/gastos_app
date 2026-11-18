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

// Color e icono por categoría: así cada gasto se reconoce de un vistazo.
IconData iconoCategoria(String categoria) {
  switch (categoria) {
    case 'Comida':
      return Icons.restaurant;
    case 'Transporte':
      return Icons.directions_car;
    case 'Casa':
      return Icons.home;
    case 'Diversión':
      return Icons.movie;
    default:
      return Icons.category;
  }
}

Color colorCategoria(String categoria) {
  switch (categoria) {
    case 'Comida':
      return Colors.orange;
    case 'Transporte':
      return Colors.blue;
    case 'Casa':
      return Colors.purple;
    case 'Diversión':
      return Colors.pink;
    default:
      return Colors.grey;
  }
}

// Validación compartida por agregar y editar: misma regla, mismo mensaje.
// Devuelve el mensaje de error, o null si descripción y monto están bien.
String? validarGasto(String descripcion, String textoMonto) {
  if (descripcion.trim().isEmpty) {
    return 'Escribe qué compraste.';
  }
  var texto = textoMonto.trim();
  // Solo números con hasta 2 decimales y un solo separador (coma o punto).
  var montoValido = RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(texto);
  if (!montoValido) {
    return 'El monto no es válido: usa solo números con máximo 2 decimales.';
  }
  var monto = double.tryParse(texto.replaceAll(',', '.'));
  if (monto == null || monto <= 0) {
    return 'El monto debe ser mayor a 0.';
  }
  return null;
}

// Convierte el texto del monto a número. Usar solo después de validar.
double parseMonto(String textoMonto) =>
    double.parse(textoMonto.trim().replaceAll(',', '.'));

class GastoState extends ChangeNotifier {
  GastoState() {
    cargar();
  }

  final gastos = <Gasto>[];
  Gasto? _ultimoEliminado;
  var _indiceUltimoEliminado = -1;

  // Al abrir la app, lee los gastos guardados en el teléfono/navegador.
  // Parche de Nemotron 3 Ultra (8-nov-2026): si la lectura falla, no se rompe la app.
  Future<void> cargar() async {
    try {
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
    } catch (_) {
      gastos.clear();
      notifyListeners();
    }
  }

  // Después de cada cambio, escribe la lista completa en el guardado local.
  Future<void> guardar() async {
    try {
      var prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'gastos',
        gastos
            .map(
              (g) => jsonEncode({
                'version': 1,
                'descripcion': g.descripcion,
                'monto': g.monto,
                'categoria': g.categoria,
              }),
            )
            .toList(),
      );
    } catch (_) {}
  }

  double get total => gastos.fold(0, (suma, g) => suma + g.monto);

  double totalPorCategoria(String categoria) =>
      gastos.where((g) => g.categoria == categoria).fold(0, (suma, g) => suma + g.monto);

  void agregar(Gasto gasto) {
    gastos.add(gasto);
    guardar();
    notifyListeners();
  }

  // Reemplaza el gasto en esa posición por el nuevo y lo guarda.
  void editar(int indice, Gasto nuevo) {
    if (indice >= 0 && indice < gastos.length) {
      gastos[indice] = nuevo;
      guardar();
      notifyListeners();
    }
  }

  void quitar(Gasto gasto) {
    _indiceUltimoEliminado = gastos.indexOf(gasto);
    if (_indiceUltimoEliminado >= 0) {
      _ultimoEliminado = gasto;
      gastos.removeAt(_indiceUltimoEliminado);
      guardar();
      notifyListeners();
    }
  }

  void deshacerEliminacion() {
    if (_ultimoEliminado != null && _indiceUltimoEliminado >= 0) {
      gastos.insert(_indiceUltimoEliminado, _ultimoEliminado!);
      _ultimoEliminado = null;
      _indiceUltimoEliminado = -1;
      guardar();
      notifyListeners();
    }
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
          cardTheme: CardThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
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
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
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

    var color = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta principal: fondo de color, cifra grande en blanco.
              Card(
                color: color.primary,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total gastado',
                        style: TextStyle(color: color.onPrimary.withValues(alpha: 0.85)),
                      ),
                      Text(
                        '\$${state.total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: color.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tus gastos se guardan en este dispositivo y ya no se borran al cerrar.',
                        style: TextStyle(color: color.onPrimary.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Por categoría',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      for (var categoria in categorias)
                        if (state.totalPorCategoria(categoria) > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: colorCategoria(categoria)
                                          .withValues(alpha: 0.15),
                                      child: Icon(
                                        iconoCategoria(categoria),
                                        color: colorCategoria(categoria),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(categoria)),
                                    Text(
                                      '${state.total > 0 ? (state.totalPorCategoria(categoria) / state.total * 100).round() : 0}%',
                                      style: TextStyle(color: color.outline),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '\$${state.totalPorCategoria(categoria).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: state.total > 0
                                        ? state.totalPorCategoria(categoria) /
                                              state.total
                                        : 0,
                                    backgroundColor: color.surfaceContainerHighest,
                                    color: colorCategoria(categoria),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      if (state.gastos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Aquí aparecerán tus categorías al agregar gastos.'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tus gastos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (state.gastos.isEmpty)
                const Text('Sin gastos todavía. Agrega el primero en la pestaña Agregar.')
              else
                for (var gasto in state.gastos)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorCategoria(gasto.categoria)
                            .withValues(alpha: 0.15),
                        child: Icon(
                          iconoCategoria(gasto.categoria),
                          color: colorCategoria(gasto.categoria),
                        ),
                      ),
                      title: Text(gasto.descripcion),
                      subtitle: Text(gasto.categoria),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${gasto.monto.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Editar',
                            onPressed: () {
                              var indice = state.gastos.indexOf(gasto);
                              showDialog(
                                context: context,
                                builder: (context) => EditarGastoDialog(
                                  indice: indice,
                                  gasto: gasto,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              state.quitar(gasto);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Gasto eliminado.'),
                                  duration: const Duration(seconds: 4),
                                  action: SnackBarAction(
                                    label: 'Deshacer',
                                    onPressed: () => state.deshacerEliminacion(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
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
    var errorValidacion = validarGasto(
      descripcionController.text,
      montoController.text,
    );
    if (errorValidacion != null) {
      setState(() {
        error = errorValidacion;
      });
      return;
    }
    var monto = parseMonto(montoController.text);
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
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agregar gasto',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: guardar,
                icon: const Icon(Icons.check),
                label: const Text('Guardar gasto'),
              ),
            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Ventana para editar un gasto: abre con los datos actuales ya escritos.
class EditarGastoDialog extends StatefulWidget {
  const EditarGastoDialog({
    super.key,
    required this.indice,
    required this.gasto,
  });

  final int indice;
  final Gasto gasto;

  @override
  State<EditarGastoDialog> createState() => _EditarGastoDialogState();
}

class _EditarGastoDialogState extends State<EditarGastoDialog> {
  late final descripcionController = TextEditingController(
    text: widget.gasto.descripcion,
  );
  late final montoController = TextEditingController(
    text: widget.gasto.monto.toStringAsFixed(2),
  );
  late var categoria = widget.gasto.categoria;
  var error = '';

  @override
  void dispose() {
    descripcionController.dispose();
    montoController.dispose();
    super.dispose();
  }

  void guardarCambios() {
    var errorValidacion = validarGasto(
      descripcionController.text,
      montoController.text,
    );
    if (errorValidacion != null) {
      setState(() {
        error = errorValidacion;
      });
      return;
    }
    context.read<GastoState>().editar(
      widget.indice,
      Gasto(
        descripcion: descripcionController.text.trim(),
        monto: parseMonto(montoController.text),
        categoria: categoria,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gasto actualizado.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar gasto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            if (error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(error, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: guardarCambios,
          icon: const Icon(Icons.check),
          label: const Text('Guardar cambios'),
        ),
      ],
    );
  }
}
