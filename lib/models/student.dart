class Student {
  final String uid;
  final String name;
  final String studentClass;
  final String imagePath;
  final String otherDetails;

  Student({
    required this.uid,
    required this.name,
    required this.studentClass,
    required this.imagePath,
    this.otherDetails = '',
  });

  // Convert Student to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'studentClass': studentClass,
      'imagePath': imagePath,
      'otherDetails': otherDetails,
    };
  }

  // Create Student from Map
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      uid: map['uid'] as String,
      name: map['name'] as String,
      studentClass: map['studentClass'] as String,
      imagePath: map['imagePath'] as String,
      otherDetails: map['otherDetails'] as String? ?? '',
    );
  }

  // Create a copy with updated fields
  Student copyWith({
    String? uid,
    String? name,
    String? studentClass,
    String? imagePath,
    String? otherDetails,
  }) {
    return Student(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      studentClass: studentClass ?? this.studentClass,
      imagePath: imagePath ?? this.imagePath,
      otherDetails: otherDetails ?? this.otherDetails,
    );
  }

  @override
  String toString() {
    return 'Student(uid: $uid, name: $name, class: $studentClass, image: $imagePath, details: $otherDetails)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Student &&
        other.uid == uid &&
        other.name == name &&
        other.studentClass == studentClass &&
        other.imagePath == imagePath &&
        other.otherDetails == otherDetails;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
    name.hashCode ^
    studentClass.hashCode ^
    imagePath.hashCode ^
    otherDetails.hashCode;
  }
}