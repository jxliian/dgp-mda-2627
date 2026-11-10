import 'domain.dart';

/// Busca por nombre o usuario, sin distinguir mayúsculas ni tildes.
List<AppUser> filterStudents(List<AppUser> students, String query) {
  final text = _normalize(query.trim());
  if (text.isEmpty) return students;
  return students
      .where(
        (student) =>
            _normalize(student.displayName).contains(text) ||
            _normalize(student.username).contains(text),
      )
      .toList();
}

String _normalize(String text) {
  const accented = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const plain = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final letter in text.toLowerCase().split('')) {
    final index = accented.indexOf(letter);
    buffer.write(index == -1 ? letter : plain[index]);
  }
  return buffer.toString();
}
