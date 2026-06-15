import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/home_repository.dart';

// ─── Events ──────────────────────────────────────────────────────────────────

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomeFetchDataEvent extends HomeEvent {
  const HomeFetchDataEvent();
}

// ─── States ──────────────────────────────────────────────────────────────────

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<Map<String, dynamic>> posts;

  const HomeLoaded({required this.posts});

  @override
  List<Object?> get props => [posts];
}

class HomeError extends HomeState {
  final String message;

  const HomeError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ─── Bloc ─────────────────────────────────────────────────────────────────────

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeRepository _repository;

  HomeBloc({HomeRepository? repository})
      : _repository = repository ?? HomeRepository(),
        super(HomeInitial()) {
    on<HomeFetchDataEvent>(_onFetchData);
  }

  Future<void> _onFetchData(
    HomeFetchDataEvent event,
    Emitter<HomeState> emit,
  ) async {
    debugPrint('[HomeBloc] Fetching data...');
    emit(HomeLoading());
    try {
      final posts = await _repository.fetchPosts();
      debugPrint('[HomeBloc] Loaded ${posts.length} items');
      emit(HomeLoaded(posts: posts));
    } catch (e, stack) {
      debugPrint('[HomeBloc] ERROR: $e');
      debugPrint('[HomeBloc] STACK: $stack');
      emit(HomeError(message: e.toString()));
    }
  }
}
