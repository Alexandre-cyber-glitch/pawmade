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
  static const _textDark = Color(0xFF2D2A26);

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

  void _onAddLiving() {
    // TODO: ouvrir l'écran d'ajout quand l'endpoint POST existera.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
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

            if (livings.isEmpty) {
              return const Center(child: Text('Aucun élément enregistré.'));
            }

            // 4. Sélection du premier élément par défaut
            final selectedLiving = _selectedLiving ?? livings.first;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête
                  const Text(
                    'My Pets',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Liste horizontale des éléments
                  SizedBox(
                    height: 122,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      children: [
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
                        AddLivingAvatar(onTap: _onAddLiving),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Carte du living sélectionné
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: LivingDetailCard(
                      key: ValueKey(
                        '${selectedLiving.type}_${selectedLiving.id}',
                      ),
                      living: selectedLiving,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
