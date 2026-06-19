import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const FMCalculatorApp());
}

class FMCalculatorApp extends StatelessWidget {
  const FMCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FM Field Strength Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _erpController = TextEditingController(text: '1.0');
  final _haatController = TextEditingController(text: '100');
  final _trufController = TextEditingController(text: '10');
  final _fmController = TextEditingController(text: '98.1');

  String _erpUnit = 'KW';
  String _haatUnit = 'FT';

  double? _dist70;
  double? _dist60;
  double? _dist34;

  // Coefficients from FMFLD.BAS
  final List<List<double>> _coeffs = [
    [3.68, 5.3680e-1, -9.4540e-2, 6.2570e-3, 0.0],
    [1.1654, -7.2486e-1, 1.6038e-1, -1.5565e-2, 5.5445e-4],
    [-9.2989e-2, 5.5882e-2, -1.2486e-2, 1.2408e-3, -4.6425e-5],
    [1.8513e-3, -1.1238e-3, 2.5306e-4, -2.5340e-5, 9.5651e-7],
    [-1.1158e-5, 6.8286e-6, -1.5485e-6, 1.5598e-7, -5.9243e-9],
  ];

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    double erp = double.tryParse(_erpController.text) ?? 0;
    double haat = double.tryParse(_haatController.text) ?? 0;
    double truf = double.tryParse(_trufController.text) ?? 0;
    double fm = double.tryParse(_fmController.text) ?? 0;

    // k = 10 / ln(10) approx 4.3429
    const double k = 4.342944819;
    double lerp;
    if (_erpUnit == 'DBK') {
      lerp = erp;
    } else {
      lerp = k * math.log(erp);
    }

    double mFactor = (_haatUnit == 'M') ? 3.280833 : 1.0;
    double kmFactor = (_haatUnit == 'M') ? 1.609344 : 1.0;

    // khat = ln(HAAT in feet)
    double khat = math.log(haat * mFactor);
    // Terrain roughness correction
    double trufAdj = 1.9 - 0.03 * truf * (1 + fm / 300);

    setState(() {
      _dist70 = _calculateDistance(70, lerp, trufAdj, khat, kmFactor);
      _dist60 = _calculateDistance(60, lerp, trufAdj, khat, kmFactor);
      _dist34 = _calculateDistance(34, lerp, trufAdj, khat, kmFactor);
    });
  }

  double _calculateDistance(double dbu, double lerp, double trufAdj, double khat, double kmFactor) {
    // ydbu = normalized field strength
    double ydbu = dbu - lerp - trufAdj;
    double z = 0;

    // 2D Polynomial approximation: Z = sum_{i=0}^4 (sum_{j=0}^4 A_{ij} * khat^j) * ydbu^i
    for (int i = 0; i <= 4; i++) {
      double m = 0;
      for (int j = 0; j <= 4; j++) {
        m += _coeffs[i][j] * math.pow(khat, j);
      }
      z += m * math.pow(ydbu, i);
    }

    // Distance in miles = exp(z). Apply conversion factor if HAAT was in meters.
    return (math.exp(z) * 10 * kmFactor).round() / 10.0;
  }

  @override
  Widget build(BuildContext context) {
    String distUnit = (_haatUnit == 'FT') ? 'MI' : 'KM';

    return Scaffold(
      appBar: AppBar(
        title: const Text('FM Field Strength Calculator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Based on Ed Westenhaver / Harrier Corp. 1979 Method',
                style: TextStyle(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _erpController,
                              decoration: const InputDecoration(
                                labelText: 'ERP (Effective Radiated Power)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<String>(
                            value: _erpUnit,
                            items: ['KW', 'DBK'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _erpUnit = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _haatController,
                              decoration: const InputDecoration(
                                labelText: 'HAAT (Height Above Avg Terrain)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<String>(
                            value: _haatUnit,
                            items: ['FT', 'M'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _haatUnit = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _trufController,
                        decoration: const InputDecoration(
                          labelText: 'Terrain Roughness (M)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fmController,
                        decoration: const InputDecoration(
                          labelText: 'FM Channel (MHz)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          double? v = double.tryParse(value);
                          if (v == null || v < 92.1 || v > 108) return 'FM Range: 92.1 - 108';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('Calculate Contours'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              if (_dist70 != null)
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Results ($distUnit):',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Divider(),
                        _buildResultRow('70 dBu (3.16 mV/m)', _dist70!, distUnit),
                        _buildResultRow('60 dBu (1.0 mV/m)', _dist60!, distUnit),
                        _buildResultRow('34 dBu (50 uV/m)', _dist34!, distUnit),
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

  Widget _buildResultRow(String label, double value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            '$value $unit',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
