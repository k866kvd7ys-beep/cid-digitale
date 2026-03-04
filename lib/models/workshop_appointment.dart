class WorkshopAppointment {
  final String id;
  final String workshopId;
  final String serviceType;
  final DateTime startTime;
  final DateTime endTime;

  WorkshopAppointment({
    required this.id,
    required this.workshopId,
    required this.serviceType,
    required this.startTime,
    required this.endTime,
  });

  factory WorkshopAppointment.fromJson(Map<String, dynamic> json) {
    return WorkshopAppointment(
      id: json['id'] as String,
      workshopId: json['workshop_id'] as String,
      serviceType: json['service_type'] as String,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
    );
  }
}
