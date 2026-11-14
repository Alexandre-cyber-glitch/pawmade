import 'package:flutter/material.dart';

import '../models/living_item.dart';
import '../service/living_api.dart';
import '../widgets/dotted_circle.dart';
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

  LivingItem? _selectedLiving;

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
                debugPrint('ERREUR CHARGEMENT LIVINGS : ${snapshot.error}');

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Impossible de charger tes éléments.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedLiving = null;
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

              debugPrint('========== LIVINGS CHARGÉS ==========');
              debugPrint('Nombre de living : ${livings.length}');

              for (final living in livings) {
                debugPrint(
                  'Living : ${living.name} | '
                  'ID : ${living.id} | '
                  'TYPE : ${living.type}',
                );
              }

              if (livings.isEmpty) {
                return const Center(child: Text('Aucun élément enregistré.'));
              }

              // 4. Sélection du premier élément par défaut
              // On conserve l'objet sélectionné directement.
              final selectedLiving = _selectedLiving ?? livings.first;

              debugPrint('========== SÉLECTION ACTUELLE ==========');
              debugPrint('Nom : ${selectedLiving.name}');
              debugPrint('ID : ${selectedLiving.id}');
              debugPrint('Type : ${selectedLiving.type}');
              debugPrint('========================================');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Pets',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Liste horizontale des éléments
                  SizedBox(
                    height: 125,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // 1. Les living existants
                        ...livings.map((living) {
                          final isSelected = identical(living, selectedLiving);

                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: LivingAvatarItem(
                              living: living,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedLiving = living;
                                });
                              },
                            ),
                          );
                        }),

                        // 2. Cercle avec point d'interrogation
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              DottedCircle(
                                size: 68,
                                color: const Color(0xFFB58A62),
                                child: const Center(
                                  child: Text(
                                    '?',
                                    style: TextStyle(
                                      fontSize: 28,
                                      color: Color(0xFFB58A62),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3. Cercle Add pet
                        Column(
                          children: [
                            DottedCircle(
                              size: 68,
                              color: const Color(0xFFB58A62),
                              child: const Center(
                                child: Icon(
                                  Icons.add,
                                  size: 30,
                                  color: Color(0xFFB58A62),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Carte du living sélectionné
                  LivingDetailCard(
                    key: ValueKey(
                      '${selectedLiving.type}_${selectedLiving.id}',
                    ),
                    living: selectedLiving,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
