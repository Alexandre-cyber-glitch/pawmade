import 'package:flutter/material.dart';

import '../models/living_detail.dart';
import '../models/living_summary.dart';
import '../service/living_api.dart';
import '../widgets/living_avatar_item.dart';
import '../widgets/living_detail_card.dart';
import '../../../core/theme/paw_colors.dart';
import '../widgets/edit/edit_living_sheet.dart';

class MyLivingsScreen extends StatefulWidget {
  /// Optionnel : les tests injectent une fausse API.
  final LivingApi? api;

  const MyLivingsScreen({super.key, this.api});

  @override
  State<MyLivingsScreen> createState() => _MyLivingsScreenState();
}

class _MyLivingsScreenState extends State<MyLivingsScreen> {
  static const _textDark = Color(0xFF2D2A26);

  late final LivingApi _livingApi = widget.api ?? LivingApi();

  /// Liste légère pour les cercles (GET /api/living).
  late Future<List<LivingSummary>> _livingsFuture;

  /// Copie locale de la liste, modifiable après une édition
  /// (pour mettre à jour un cercle sans recharger toute la liste).
  List<LivingSummary>? _livings;

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
      _livings = livings;
      if (livings.isNotEmpty && mounted) {
        final stillExists = livings.any((l) => l.id == _selectedId);
        _selectLiving(stillExists ? _selectedId! : livings.first.id);
      }
      return livings;
    });
    _livingsFuture.ignore(); // même raison que dans _selectLiving
  }

  void _selectLiving(int id) {
    final future = _livingApi.findById(id);
    // L'erreur peut arriver avant que le FutureBuilder ne s'abonne :
    // on la marque comme "gérée" (le FutureBuilder la reçoit quand même
    // et affiche le message + Réessayer).
    future.ignore();
    setState(() {
      _selectedId = id;
      _detailFuture = future;
    });
  }

  Future<void> _refresh() async {
    setState(_loadLivings);
    try {
      await _livingsFuture;
    } catch (_) {
      // Erreur déjà affichée par le FutureBuilder (vue Réessayer).
    }
  }

  /// Ouvre le bloc d'édition. Au retour, on utilise directement le détail
  /// renvoyé par le back : la carte ET le cercle sont mis à jour sans
  /// nouvel appel réseau.
  Future<void> _openEdit(LivingDetail detail) async {
    final updated = await showEditLivingSheet(
      context,
      living: detail,
      api: _livingApi,
      // Une photo changée est déjà enregistrée : on rafraîchit tout de suite.
      onPhotoChanged: _applyDetail,
    );
    if (updated == null || !mounted) return;

    _applyDetail(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${updated.name} updated'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: PawColors.textDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Remplace le détail affiché et met à jour le cercle correspondant.
  void _applyDetail(LivingDetail updated) {
    if (!mounted) return;
    setState(() {
      if (updated.id == _selectedId) {
        _detailFuture = Future.value(updated);
      }
      _livings = [
        for (final l in _livings ?? <LivingSummary>[])
          l.id == updated.id
              ? LivingSummary(
                  id: updated.id,
                  name: updated.name,
                  type: updated.type,
                  avatarUrl: updated.avatarUrl,
                )
              : l,
      ];
    });
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
            final livings = _livings ?? snapshot.data ?? [];

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
        final waiting = snapshot.connectionState != ConnectionState.done;
        final data = snapshot.data;

        if (!waiting && snapshot.hasError) {
          child = _ErrorView(
            key: const ValueKey('detail_error'),
            message: 'Impossible de charger le détail.',
            onRetry: () {
              if (_selectedId != null) _selectLiving(_selectedId!);
            },
          );
        } else if (data != null && data.id == _selectedId) {
          // On garde la carte affichée tant que c'est le même living
          // (ex. juste après une édition) : pas de clignotement.
          final editable = data.isDog || data.isPlant;
          child = LivingDetailCard(
            key: ValueKey('detail_${data.id}'),
            living: data,
            onEdit: editable ? () => _openEdit(data) : null,
          );
        } else {
          child = const LivingDetailCardSkeleton(
            key: ValueKey('detail_loading'),
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
