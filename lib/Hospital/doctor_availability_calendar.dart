import 'package:flutter/material.dart';
import 'package:nhap/widgets/profile_avatar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../Components/booking_helper.dart';

class DoctorAvailabilityCalendar extends StatefulWidget {
  final String doctorId;
  final String hospitalId;

  const DoctorAvailabilityCalendar({
    Key? key,
    required this.doctorId,
    required this.hospitalId,
  }) : super(key: key);

  @override
  _DoctorAvailabilityCalendarState createState() =>
      _DoctorAvailabilityCalendarState();
}

class _DoctorAvailabilityCalendarState
    extends State<DoctorAvailabilityCalendar> {
  int activeDays = 5;
  int offDays = 2;
  int shiftSwitch = 5;
  DateTime shiftStart = DateTime.now();
  Set<DateTime> holidays = {};
  Map<String, dynamic> shiftTimings = {};
  String doctorImage = '';

  @override
  void initState() {
    super.initState();
    _fetchDoctorSchedule();
    _fetchHospitalShiftTimings();
    _fetchGlobalHolidays();
    _fetchDoctorImage();
  }

  Future<void> _fetchDoctorSchedule() async {
    DocumentSnapshot scheduleSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.doctorId)
        .collection('Schedule')
        .doc(widget.doctorId)
        .get();

    if (scheduleSnapshot.exists) {
      setState(() {
        activeDays = scheduleSnapshot['Active Days'] ?? 5;
        offDays = scheduleSnapshot['Off Days'] ?? 2;
        shiftSwitch = scheduleSnapshot['Shift Switch'] ?? 5;
        shiftStart = (scheduleSnapshot['Shift Start'] as Timestamp).toDate();
      });
    }
  }

  Future<void> _fetchHospitalShiftTimings() async {
    DocumentSnapshot hospitalSnapshot = await FirebaseFirestore.instance
        .collection('Chamber')
        .doc(widget.hospitalId)
        .get();

    if (hospitalSnapshot.exists) {
      setState(() {
        shiftTimings =
        Map<String, dynamic>.from(hospitalSnapshot['Shift Timings'] ?? {});
      });
    }
  }

  Future<void> _fetchGlobalHolidays() async {
    QuerySnapshot holidaySnapshot =
    await FirebaseFirestore.instance.collection('Holidays').get();

    setState(() {
      holidays = holidaySnapshot.docs.map((doc) {
        Timestamp timestamp = doc['Date'];
        return timestamp.toDate();
      }).toSet();
    });
  }

  Future<void> _fetchDoctorImage() async {
    DocumentSnapshot doctorSnapshot = await FirebaseFirestore.instance
        .collection('Users')
        .doc(widget.doctorId)
        .get();

    if (doctorSnapshot.exists) {
      setState(() {
        doctorImage = doctorSnapshot['User Pic'] ?? '';
      });
    }
  }

  bool _isDoctorActive(DateTime day) {
    if (day.isBefore(shiftStart) ||
        holidays.contains(DateTime(day.year, day.month, day.day))) {
      return false;
    }

    int daysSinceStart = day.difference(shiftStart).inDays;
    int cycleLength = activeDays + offDays;

    return (daysSinceStart % cycleLength) < activeDays;
  }

  String _getDoctorShift(DateTime day) {
    int daysSinceStart = day.difference(shiftStart).inDays;
    int activePeriod = daysSinceStart % (activeDays + offDays);

    if (activePeriod < shiftSwitch) {
      return "Morning";
    } else if (activePeriod < 2 * shiftSwitch) {
      return "Afternoon";
    } else {
      return "Night";
    }
  }

  void _showShiftDetails(BuildContext context, DateTime day) {
    String shift = _getDoctorShift(day);
    Map<String, dynamic>? timingMap = shiftTimings[shift];

    String timingText;
    DateTime? bookingDateTime;
    if (timingMap != null && timingMap is Map<String, dynamic>) {
      String start = timingMap['Start'] ?? "Unavailable";
      String end = timingMap['End'] ?? "Unavailable";

      if (start != "Unavailable") {
        DateFormat dateFormat = DateFormat("hh:mm a");
        try {
          DateTime parsedStartTime = dateFormat.parse(start);
          bookingDateTime = DateTime(
            day.year,
            day.month,
            day.day,
            parsedStartTime.hour,
            parsedStartTime.minute,
          );
        } catch (e) {
          print("Error parsing time: $e");
        }
      }

      timingText = "Start: $start\nEnd: $end";
    } else {
      timingText = "Timings Unavailable";
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // White dialog background
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shift Details',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              ProfileAvatar.circle(
                imageUrl: doctorImage,
                radius: 20,
                backgroundColor: Colors.grey[300],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date: ${DateFormat('yyyy-MM-dd').format(day)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Shift:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                timingText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Guide:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Text(
                'Book an appointment for a seamless visit!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (bookingDateTime != null) {
                  handleBookAppointment(
                    context,
                    doctorId: widget.doctorId,
                    hospitalId: widget.hospitalId,
                    selectedDate: bookingDateTime,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87, // Dark button
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Book Appointment',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white, // White dialog background
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose a date',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 30)),
              focusedDay: DateTime.now(),
              calendarStyle: CalendarStyle(
                todayDecoration: const BoxDecoration(
                  color: Colors.grey, // Grey for today
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: const TextStyle(color: Colors.black87),
                weekendTextStyle: const TextStyle(color: Colors.black54),
                outsideTextStyle: const TextStyle(color: Colors.grey),
                disabledTextStyle: const TextStyle(color: Colors.grey),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  if (holidays.contains(DateTime(day.year, day.month, day.day))) {
                    return Center(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54, // Dark grey for holidays
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  } else if (_isDoctorActive(day)) {
                    return GestureDetector(
                      onTap: () => _showShiftDetails(context, day),
                      child: Center(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black87, // Dark for active days
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                },
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black87),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black87),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.black87),
                weekendStyle: TextStyle(color: Colors.black54),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                LegendItem(color: Colors.black87, text: 'Available'),
                LegendItem(color: Colors.black54, text: 'Holiday'),
                LegendItem(color: Colors.grey, text: 'Today'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const LegendItem({required this.color, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: Colors.black87, fontSize: 12),
        ),
      ],
    );
  }
}