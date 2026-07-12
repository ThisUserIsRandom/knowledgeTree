import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:knowledgetree/features/connector/domain/ai_profile.dart';
import 'package:knowledgetree/features/connector/data/profile_store.dart';

class ProfileState {
  final List<AiProfile> profiles;
  final String? activeId;

  const ProfileState({this.profiles = const [], this.activeId});

  ProfileState copyWith({List<AiProfile>? profiles, String? activeId}) => ProfileState(
        profiles: profiles ?? this.profiles,
        activeId: activeId ?? this.activeId,
      );

  AiProfile? get active {
    if (activeId == null) return null;
    for (final p in profiles) {
      if (p.id == activeId) return p;
    }
    return null;
  }
}

/// Single source of truth for AI profiles. Mutations persist via
/// [ProfileStore] and push the active profile to the backend so every
/// consumer (settings, chat, server routing) stays in sync.
class ProfileStoreNotifier extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    _load();
    return const ProfileState();
  }

  Future<void> _load() async {
    final profiles = await ProfileStore.loadProfiles();
    final activeId = await ProfileStore.loadActiveId();
    state = state.copyWith(
      profiles: profiles,
      activeId: activeId ?? profiles.firstOrNull?.id,
    );
  }

  Future<void> setActive(AiProfile p) async {
    await ProfileStore.saveActiveId(p.id);
    await ProfileStore.applyActive(p);
    state = state.copyWith(activeId: p.id);
  }

  Future<void> saveProfile(AiProfile p, {bool makeActive = false}) async {
    final list = [...state.profiles];
    final idx = list.indexWhere((e) => e.id == p.id);
    if (idx >= 0) {
      list[idx] = p;
    } else {
      list.add(p);
    }
    await ProfileStore.saveProfiles(list);

    String? activeId = state.activeId;
    // Re-apply when this profile is (or becomes) the active one, so edits to
    // the active profile are reflected in prefs, the backend, and requests.
    final isActive = activeId == p.id;
    if (makeActive || isActive || activeId == null || list.length == 1) {
      activeId = p.id;
      await ProfileStore.saveActiveId(p.id);
      await ProfileStore.applyActive(p);
    }
    state = state.copyWith(profiles: list, activeId: activeId);
  }

  Future<void> deleteProfile(AiProfile p) async {
    final list = state.profiles.where((e) => e.id != p.id).toList();
    await ProfileStore.saveProfiles(list);

    String? activeId = state.activeId;
    if (activeId == p.id) {
      if (list.isNotEmpty) {
        activeId = list.first.id;
        await ProfileStore.saveActiveId(activeId);
        await ProfileStore.applyActive(list.first);
      } else {
        activeId = null;
      }
    }
    state = state.copyWith(profiles: list, activeId: activeId);
  }
}

final profileProvider =
    NotifierProvider<ProfileStoreNotifier, ProfileState>(ProfileStoreNotifier.new);
