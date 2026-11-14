import 'package:flutter/material.dart';

import '../models/living_item.dart';
import '../service/living_api.dart';
import '../widgets/living_avatar_item.dart';
import '../widgets/living_detail_card.dart';

class MyLivingsScreen extends StatefulWidget {
  const MyLivingsScreen({super.key});

  @override
  State<MyLivingsScreen> createState() => _MyLivingsScreenState();
}

class _MyLivingsScreenState extends State<MyLivingsScreen> {
  final LivingApi _livingApi = LivingApi();

  late Future<List<LivingItem>> _livingsFuture;

  int? _selectedLivingId;

  @override
  void initState() {
    super.initState();
    _loadLivings();
  }

  void _loadLivings() {
    _livingsFuture = _livingApi.findAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<List<LivingItem>>(
            future: _livingsFuture,
            builder: (context, snapshot) {
              // 1. Chargement
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // 2. Erreur
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Impossible de charger tes éléments.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loadLivings();
                          });
                        },
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                );
              }

              // 3. Données récupérées
              final livings = snapshot.data ?? [];

              if (livings.isEmpty) {
                return const Center(child: Text('Aucun élément enregistré.'));
              }

              // 4. Sélection du premier élément par défaut
              final selectedLiving = livings.firstWhere(
                (living) => living.id == _selectedLivingId,
                orElse: () => livings.first,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Living',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Liste horizontale des éléments
                  SizedBox(
                    height: 115,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: livings.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final living = livings[index];

                        return LivingAvatarItem(
                          living: living,
                          isSelected: living.id == selectedLiving.id,
                          onTap: () {
                            setState(() {
                              _selectedLivingId = living.id;
                            });
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Carte de l'élément sélectionné
                  LivingDetailCard(living: selectedLiving),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
