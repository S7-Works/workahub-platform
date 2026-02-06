import 'dart:async';
import 'dart:typed_data';
import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:workahub_app/src/flatbuffers/monitoring_workahub.monitoring_generated.dart' as fbs;
import 'package:workahub_app/src/rust/api/monitor.dart';
import 'package:workahub_app/src/rust/api/media.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Stats History for Graphs
  final List<FlSpot> _cpuPoints = [];
  final List<FlSpot> _memPoints = [];
  double _timeCounter = 0;
  
  // Current Stats
  int _mouseClicks = 0;
  int _keyPresses = 0;
  
  // Media State
  Uint8List? _liveSnapshot;
  bool _isRecording = false;
  String? _currentRecordingId;
  Timer? _statsTimer;
  Timer? _mediaTimer;

  @override
  void initState() {
    super.initState();
    // Start Monitoring Inputs
    startInputMonitoring();
    
    // Polling Stats (1s)
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchStats();
    });

    // Polling Snapshot (if recording) - 500ms
    _mediaTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isRecording && _currentRecordingId != null) {
        _fetchSnapshot();
      }
    });
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _mediaTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      // 1. Get FlatBuffer Blob
      final blob = await getMonitoringPacketFbs();
      
      // 2. Decode
      final buffer = fb.BufferContext.fromBytes(blob);
      final packet = fbs.MonitoringPacket(buffer, 0); // Root starts at 0? Usually root offset is at 0.
      // Actually, root object is accessed via root accessor. 
      // The generated code typically has a static method or constructor for root.
      // Let's rely on standard flatbuffers usage: 
      // fbs.MonitoringPacket(buffer, buffer.readInt32(0) + 0) ? 
      // No, usually `new MonitoringPacket(buffer, rootOffset)`
      // Let's try standard generated read.
      
      // Note: Rust flatbuffers adds a u32 size header usually? 
      // Or `builder.finished_data()` returns the raw buffer.
      // Standard: read Uint32 at 0 -> offset.
      
      // Checking generated code structure implies we might need to verify reading.
      // Assuming standard:
      final rootOffset = buffer.readInt32(0); // Offset to root table
      final data = fbs.MonitoringPacket(buffer, rootOffset);
      
      if (data.input != null) {
        setState(() {
          _mouseClicks += data.input!.mouseClicks.toInt();
          _keyPresses += data.input!.keyPresses.toInt();
        });
      }

      if (data.system != null) {
        setState(() {
          _timeCounter++;
          
          // CPU
          _cpuPoints.add(FlSpot(_timeCounter, data.system!.cpuUsage));
          if (_cpuPoints.length > 60) _cpuPoints.removeAt(0);
          
          // Mem (GB)
          final memUsedGb = data.system!.memoryUsed / (1024 * 1024 * 1024);
          _memPoints.add(FlSpot(_timeCounter, memUsedGb));
          if (_memPoints.length > 60) _memPoints.removeAt(0);
        });
      }
    } catch (e) {
      print("Stats error: $e");
    }
  }

  Future<void> _fetchSnapshot() async {
    try {
      if (_currentRecordingId == null) return;
      final imageBytes = await captureLiveSnapshot(pipelineId: _currentRecordingId!);
      setState(() {
        _liveSnapshot = imageBytes;
      });
    } catch (e) {
      // Only print if not "pipeline not found" (which happens on stop)
      if (!e.toString().contains("not found")) {
        print("Snapshot error: $e");
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // STOP
      if (_currentRecordingId != null) {
        await stopPipeline(id: _currentRecordingId!);
      }
      setState(() {
        _isRecording = false;
        _currentRecordingId = null;
        _liveSnapshot = null;
      });
    } else {
      // START
      final id = const Uuid().v4();
      final dir = await getApplicationDocumentsDirectory();
      final path = "${dir.path}/rec_$id.mp4";
      
      await startScreenRecording(id: id, sinkPath: path);
      
      setState(() {
        _isRecording = true;
        _currentRecordingId = id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Workahub Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top Row: Stats & Controls
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats Card
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Session Input Stats", style: TextStyle(fontWeight: FontWeight.bold)),
                          const Divider(),
                          Text("Mouse Clicks: $_mouseClicks"),
                          Text("Key Presses: $_keyPresses"),
                          const SizedBox(height: 10),
                          const Text("System Load", style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 100,
                            child: LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: 100,
                                titlesData: const FlTitlesData(show: false),
                                borderData: FlBorderData(show: true),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _cpuPoints,
                                    isCurved: true,
                                    color: Colors.blue,
                                    barWidth: 2,
                                    dotData: const FlDotData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Center(child: Text("CPU Usage %", style: TextStyle(fontSize: 10))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Controls & Media
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _toggleRecording,
                        icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
                        label: Text(_isRecording ? "Stop Recording" : "Start Recording"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecording ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 250,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: _liveSnapshot != null
                            ? Image.memory(_liveSnapshot!, gaplessPlayback: true, fit: BoxFit.contain)
                            : Center(
                                child: Text(
                                  _isRecording ? "Waiting for preview..." : "Preview Disabled
(Start Recording to see live feed)",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white54),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
