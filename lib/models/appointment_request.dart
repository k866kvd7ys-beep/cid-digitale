class AppointmentRequest {
  AppointmentRequest({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.serviceType,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.durationMinutes,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.licensePlate,
    required this.status,
    this.notes,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String serviceType;
  final DateTime appointmentDate;
  final String appointmentTime;
  final int durationMinutes;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? licensePlate;
  final String status;
  final String? notes;

  factory AppointmentRequest.fromMap(Map<String, dynamic> map) {
    final createdStr = map['created_at']?.toString();
    final updatedStr = map['updated_at']?.toString();
    final dateStr = map['appointment_date']?.toString();

    return AppointmentRequest(
      id: (map['id'] ?? '').toString(),
      createdAt: DateTime.tryParse(createdStr ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(updatedStr ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      serviceType: (map['service_type'] ?? '').toString(),
      appointmentDate: DateTime.tryParse(dateStr ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      appointmentTime: (map['appointment_time'] ?? '').toString(),
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 60,
      customerName: (map['customer_name'] ?? map['customerName']) as String?,
      customerPhone: (map['phone'] ??
          map['customer_phone'] ??
          map['customerPhone']) as String?,
      customerEmail: (map['email'] ??
          map['customer_email'] ??
          map['customerEmail']) as String?,
      licensePlate: (map['license_plate'] ?? map['licensePlate']) as String?,
      status: (map['status'] ?? 'pending').toString(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'service_type': serviceType,
      'appointment_date': appointmentDate.toIso8601String().substring(0, 10),
      'appointment_time': appointmentTime,
      'duration_minutes': durationMinutes,
      'customer_name': customerName,
      'phone': customerPhone,
      'email': customerEmail,
      'license_plate': licensePlate,
      'status': status,
      'notes': notes,
    };
  }
}
