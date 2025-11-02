// lib/models/meal_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType { breakfast, lunch, dinner }

class MealService {
  final String id;
  final DateTime date;
  final MealType mealType;
  final int numberOfPeople;
  final String? notes;
  final DateTime createdAt;

  MealService({
    required this.id,
    required this.date,
    required this.mealType,
    required this.numberOfPeople,
    this.notes,
    required this.createdAt,
  });

  factory MealService.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealService(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      mealType: MealType.values.firstWhere(
            (e) => e.toString() == data['mealType'],
        orElse: () => MealType.lunch,
      ),
      numberOfPeople: data['numberOfPeople'] ?? 0,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'mealType': mealType.toString(),
      'numberOfPeople': numberOfPeople,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String getMealTypeLabel() {
    switch (mealType) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
    }
  }

  String getMealTypeEmoji() {
    switch (mealType) {
      case MealType.breakfast:
        return '🌅';
      case MealType.lunch:
        return '☀️';
      case MealType.dinner:
        return '🌙';
    }
  }

  MealService copyWith({
    String? id,
    DateTime? date,
    MealType? mealType,
    int? numberOfPeople,
    String? notes,
    DateTime? createdAt,
  }) {
    return MealService(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      numberOfPeople: numberOfPeople ?? this.numberOfPeople,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
