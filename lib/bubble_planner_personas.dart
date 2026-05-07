import 'package:flutter/material.dart';

/// Жизненный профиль: от него зависят набор пузырей (категорий) и привязка задач.
enum BubblePlannerPersona {
  general,
  student,
  parent,
}

BubblePlannerPersona bubblePlannerPersonaFromStorage(String? raw) {
  switch (raw) {
    case 'student':
      return BubblePlannerPersona.student;
    case 'parent':
      return BubblePlannerPersona.parent;
    case 'general':
    default:
      return BubblePlannerPersona.general;
  }
}

/// Стабильные «семантические» корзины для переноса задач между профилями.
enum BubbleSemanticCategory {
  kids,
  work,
  shopping,
  health,
  general,
  hobby,
  sport,
}

BubbleSemanticCategory semanticFromAnyCategoryId(String id) {
  switch (id) {
    case 'kids':
      return BubbleSemanticCategory.kids;
    case 'work':
    case 'study':
    case 'parttime':
      return BubbleSemanticCategory.work;
    case 'shopping':
    case 'groceries':
      return BubbleSemanticCategory.shopping;
    case 'health':
    case 'family_health':
      return BubbleSemanticCategory.health;
    case 'hobby':
    case 'personal':
      return BubbleSemanticCategory.hobby;
    case 'sport':
      return BubbleSemanticCategory.sport;
    case 'school':
      return BubbleSemanticCategory.kids;
    case 'general':
    case 'exams':
    case 'campus':
    case 'home':
      return BubbleSemanticCategory.general;
    default:
      return BubbleSemanticCategory.general;
  }
}

String categoryIdForSemantic(
  BubblePlannerPersona p,
  BubbleSemanticCategory s,
) {
  switch (p) {
    case BubblePlannerPersona.general:
      switch (s) {
        case BubbleSemanticCategory.kids:
          return 'kids';
        case BubbleSemanticCategory.work:
          return 'work';
        case BubbleSemanticCategory.shopping:
          return 'shopping';
        case BubbleSemanticCategory.health:
          return 'health';
        case BubbleSemanticCategory.general:
          return 'general';
        case BubbleSemanticCategory.hobby:
          return 'personal';
        case BubbleSemanticCategory.sport:
          return 'sport';
      }
    case BubblePlannerPersona.student:
      switch (s) {
        case BubbleSemanticCategory.kids:
          return 'personal';
        case BubbleSemanticCategory.work:
          return 'work';
        case BubbleSemanticCategory.shopping:
          return 'personal';
        case BubbleSemanticCategory.health:
          return 'personal';
        case BubbleSemanticCategory.general:
          return 'personal';
        case BubbleSemanticCategory.hobby:
          return 'personal';
        case BubbleSemanticCategory.sport:
          return 'sport';
      }
    case BubblePlannerPersona.parent:
      switch (s) {
        case BubbleSemanticCategory.kids:
          return 'kids';
        case BubbleSemanticCategory.work:
          return 'work';
        case BubbleSemanticCategory.shopping:
          return 'groceries';
        case BubbleSemanticCategory.health:
          return 'family_health';
        case BubbleSemanticCategory.general:
          return 'home';
        case BubbleSemanticCategory.hobby:
          return 'personal';
        case BubbleSemanticCategory.sport:
          return 'sport';
      }
  }
}

/// При смене профиля или загрузке задач с «чужими» id — нормализуем под текущий профиль.
String migrateCategoryIdToPersona(
  String currentId,
  BubblePlannerPersona targetPersona,
) {
  final sem = semanticFromAnyCategoryId(currentId);
  return categoryIdForSemantic(targetPersona, sem);
}

String categoryTagForCategoryId(String id) => id.toUpperCase();

/// Раскладка пузырей (цвета/позиции); подписи — по ключам в translations.
class BubbleSlotLayout {
  const BubbleSlotLayout({
    required this.id,
    required this.titleKey,
    required this.color,
    required this.position,
    required this.size,
  });

  final String id;
  final String titleKey;
  final Color color;
  final Offset position;
  final double size;
}

List<BubbleSlotLayout> slotLayoutsForPersona(BubblePlannerPersona p) {
  switch (p) {
    case BubblePlannerPersona.general:
      return const [
        BubbleSlotLayout(
          id: 'kids',
          titleKey: 'bubbleGenKids',
          color: Color(0xFFFFB36A),
          position: Offset(0.16, 0.22),
          size: 128,
        ),
        BubbleSlotLayout(
          id: 'work',
          titleKey: 'bubbleGenWork',
          color: Color(0xFF67A9FF),
          position: Offset(0.76, 0.2),
          size: 122,
        ),
        BubbleSlotLayout(
          id: 'shopping',
          titleKey: 'bubbleGenShopping',
          color: Color(0xFFB88BFF),
          position: Offset(0.25, 0.48),
          size: 126,
        ),
        BubbleSlotLayout(
          id: 'health',
          titleKey: 'bubbleGenHealth',
          color: Color(0xFF65DEA3),
          position: Offset(0.76, 0.53),
          size: 118,
        ),
        BubbleSlotLayout(
          id: 'general',
          titleKey: 'bubbleGenGeneral',
          color: Color(0xFF9CA3AF),
          position: Offset(0.14, 0.77),
          size: 106,
        ),
        BubbleSlotLayout(
          id: 'personal',
          titleKey: 'bubbleGenPersonal',
          color: Color(0xFFFF8FAB),
          position: Offset(0.5, 0.34),
          size: 114,
        ),
        BubbleSlotLayout(
          id: 'sport',
          titleKey: 'bubbleGenSport',
          color: Color(0xFF4ECDC4),
          position: Offset(0.55, 0.74),
          size: 112,
        ),
      ];
    case BubblePlannerPersona.student:
      return const [
        BubbleSlotLayout(
          id: 'study',
          titleKey: 'bubbleStStudy',
          color: Color(0xFF5B8DEF),
          position: Offset(0.18, 0.2),
          size: 126,
        ),
        BubbleSlotLayout(
          id: 'exams',
          titleKey: 'bubbleStExams',
          color: Color(0xFFE85D75),
          position: Offset(0.74, 0.2),
          size: 118,
        ),
        BubbleSlotLayout(
          id: 'campus',
          titleKey: 'bubbleStCampus',
          color: Color(0xFF9B7BED),
          position: Offset(0.46, 0.34),
          size: 118,
        ),
        BubbleSlotLayout(
          id: 'work',
          titleKey: 'bubbleStWork',
          color: Color(0xFF4ECDC4),
          position: Offset(0.78, 0.5),
          size: 116,
        ),
        BubbleSlotLayout(
          id: 'personal',
          titleKey: 'bubbleStPersonal',
          color: Color(0xFF9CA3AF),
          position: Offset(0.16, 0.76),
          size: 108,
        ),
        BubbleSlotLayout(
          id: 'personal',
          titleKey: 'bubbleStPersonal',
          color: Color(0xFFFF8FAB),
          position: Offset(0.28, 0.54),
          size: 114,
        ),
        BubbleSlotLayout(
          id: 'sport',
          titleKey: 'bubbleStSport',
          color: Color(0xFF65DEA3),
          position: Offset(0.58, 0.74),
          size: 112,
        ),
      ];
    case BubblePlannerPersona.parent:
      return const [
        BubbleSlotLayout(
          id: 'kids',
          titleKey: 'bubbleParKids',
          color: Color(0xFFFFB36A),
          position: Offset(0.16, 0.2),
          size: 126,
        ),
        BubbleSlotLayout(
          id: 'school',
          titleKey: 'bubbleParSchool',
          color: Color(0xFF67A9FF),
          position: Offset(0.76, 0.2),
          size: 118,
        ),
        BubbleSlotLayout(
          id: 'home',
          titleKey: 'bubbleParHome',
          color: Color(0xFFC4A574),
          position: Offset(0.3, 0.47),
          size: 120,
        ),
        BubbleSlotLayout(
          id: 'work',
          titleKey: 'bubbleParWork',
          color: Color(0xFF65DEA3),
          position: Offset(0.74, 0.48),
          size: 116,
        ),
        BubbleSlotLayout(
          id: 'family_health',
          titleKey: 'bubbleParHealth',
          color: Color(0xFFB88BFF),
          position: Offset(0.14, 0.76),
          size: 108,
        ),
        BubbleSlotLayout(
          id: 'personal',
          titleKey: 'bubbleParPersonal',
          color: Color(0xFFFF8FAB),
          position: Offset(0.5, 0.3),
          size: 112,
        ),
        BubbleSlotLayout(
          id: 'sport',
          titleKey: 'bubbleParSport',
          color: Color(0xFF4ECDC4),
          position: Offset(0.54, 0.72),
          size: 110,
        ),
        BubbleSlotLayout(
          id: 'groceries',
          titleKey: 'bubbleParGroceries',
          color: Color(0xFF9CA3AF),
          position: Offset(0.3, 0.82),
          size: 98,
        ),
      ];
  }
}

Set<String> categoryIdsForPersona(BubblePlannerPersona p) =>
    slotLayoutsForPersona(p).map((s) => s.id).toSet();

/// Текст парсера задач → семантика → id в текущем профиле.
String categoryIdFromParsedLabel(String label, BubblePlannerPersona p) {
  final BubbleSemanticCategory sem;
  switch (label) {
    case 'Дети':
      sem = BubbleSemanticCategory.kids;
      break;
    case 'Работа':
    case 'Финансы':
      sem = BubbleSemanticCategory.work;
      break;
    case 'Покупки':
      sem = BubbleSemanticCategory.shopping;
      break;
    case 'Здоровье':
      sem = BubbleSemanticCategory.health;
      break;
    case 'Дом':
    case 'Общее':
    default:
      sem = BubbleSemanticCategory.general;
      break;
  }
  return categoryIdForSemantic(p, sem);
}
