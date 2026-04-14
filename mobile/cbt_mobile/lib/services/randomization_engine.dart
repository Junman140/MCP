import 'dart:math';
import '../models/exam.dart';

class RandomizationEngine {
  final int seed;
  late Random _random;

  RandomizationEngine(this.seed) {
    _random = Random(seed);
  }

  List<Question> randomizeQuestions(List<Question> questions) {
    final shuffled = List<Question>.from(questions);
    shuffled.shuffle(_random);
    return shuffled;
  }

  List<Option> randomizeOptions(List<Option> options) {
    final shuffled = List<Option>.from(options);
    shuffled.shuffle(_random);
    return shuffled;
  }
}
