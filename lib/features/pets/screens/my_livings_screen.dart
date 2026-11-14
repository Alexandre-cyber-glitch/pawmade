import 'package:flutter/material.dart';

import '../models/living_detail.dart';
import '../models/living_summary.dart';
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

  /// Liste légère pour les cercles (GET /api/living).
  late Future<List<LivingSummary>> _livingsFuture;

  /// Id du cercle sélectionné.
  int? _selectedId;

  /// Détail du living sélectionné (GET /api/living/{id}).
  /// Re-fetché à chaque clic pour avoir les infos à jour.
  Future<LivingDetail>? _detailFuture;

  @override
  void initState() {
    super.initState();
    _loadLivings();
  }

  /// Charge les summaries, puis le détail du sélectionné
  /// (le premier par défaut, ou celui déjà choisi s'il existe encore).
  void _loadLivings() {
    _livingsFuture = _livingApi.findAll().then((livings) {
      if (livings.isNotEmpty && mounted) {
        final stillExists = livings.any((l) => l.id == _selectedId);
        _selectLiving(stillExists ? _selectedId! : livings.first.id);
      }
      return livings;
    });
  }

  void _selectLiving(int id) {
    setState(() {
      _selectedId = id;
      _detailFuture = _livingApi.findById(id);
    });
  }

  Future<void> _refresh() async {
    setState(_loadLivings);
    await _livingsFuture;
  }

  void _onAddLiving() {
    // TODO: ouvrir l'écran d'ajout quand l'endpoint POST existera.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: FutureBuilder<List<LivingSummary>>(
          future: _livingsFuture,
          builder: (context, snapshot) {
            // 1. Chargement
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // 2. Erreur
            if (snapshot.hasError) {
              return _ErrorView(
                message: 'Impossible de charger tes éléments.',
                onRetry: () => setState(_loadLivings),
              );
            }

            // 3. Données récupérées
            final livings = snapshot.data ?? [];

            if (livings.isEmpty) {
              return const Center(child: Text('Aucun élément enregistré.'));
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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

                    // Cercles (stories)
                    SizedBox(
                      height: 140,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        children: [
                          ...livings.map(
                            (living) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: LivingAvatarItem(
                                living: living,
                                isSelected: living.id == _selectedId,
                                onTap: () => _selectLiving(living.id),
                              ),
                            ),
                          ),
                          AddLivingAvatar(onTap: _onAddLiving),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Carte du living sélectionné
                    _buildDetail(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetail() {
    return FutureBuilder<LivingDetail>(
      future: _detailFuture,
      builder: (context, snapshot) {
        final Widget child;

        if (snapshot.hasError) {
          child = _ErrorView(
            key: const ValueKey('detail_error'),
            message: 'Impossible de charger le détail.',
            onRetry: () {
              if (_selectedId != null) _selectLiving(_selectedId!);
            },
          );
        } else if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData) {
          child = const LivingDetailCardSkeleton(
            key: ValueKey('detail_loading'),
          );
        } else {
          final detail = snapshot.data!;
          child = LivingDetailCard(
            key: ValueKey('detail_${detail.id}'),
            living: detail,
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: child,
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
