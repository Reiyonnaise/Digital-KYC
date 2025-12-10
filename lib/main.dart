// digital_kyc_modern_main.dart
// Modernized single-file Flutter demo for the Digital KYC flow
// Keep your backend URL in `baseUrl` (emulator: 10.0.2.2)

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// TODO: change this to your backend URL
const String baseUrl = 'http://10.0.2.2:8000';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital KYC Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardTheme(
          elevation: 3,
          shadowColor: Colors.indigo.withOpacity(0.1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDCE1ED)),
          ),
        ),
      ),
      home: const KycFlowPage(),
    );
  }
}

enum KycStep { selectDoc, uploadDoc, uploadSelfie, uploadLiveSelfie, done }

class KycFlowPage extends StatefulWidget {
  const KycFlowPage({super.key});

  @override
  State<KycFlowPage> createState() => _KycFlowPageState();
}

class _KycFlowPageState extends State<KycFlowPage> {
  final ImagePicker _picker = ImagePicker();

  KycStep _currentStep = KycStep.selectDoc;

  // state variables
  String? _kycId;
  String? _selectedDocType;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _customerIdController =
      TextEditingController(text: 'CUST123');
  final TextEditingController _docNumberController = TextEditingController();

  XFile? _docImage;
  XFile? _selfieImage;
  XFile? _liveSelfieImage;

  bool _loading = false;
  String? _statusMessage;
  String? _kycStatus; // IN_PROGRESS / APPROVED / REJECTED
  String? _rejectionReason;

  // ---------- Helpers ----------

  void _showSnack(String msg, {Color? color}) {
    final snack = SnackBar(
      content: Text(msg),
      backgroundColor: color,
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  Future<XFile?> _pick(ImageSource src, {int quality = 80}) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: src,
        imageQuality: quality,
      );
      return file;
    } catch (e) {
      _showSnack('Image pick error: $e');
      return null;
    }
  }

  Future<void> _pickImageForDoc() async {
    final file = await _pick(ImageSource.camera);
    if (file == null) return;
    setStateIfMounted(() => _docImage = file);
  }

  Future<void> _pickSelfie() async {
    final file = await _pick(ImageSource.camera);
    if (file == null) return;
    setStateIfMounted(() => _selfieImage = file);
  }

  Future<void> _pickLiveSelfie() async {
    final file = await _pick(ImageSource.camera);
    if (file == null) return;
    setStateIfMounted(() => _liveSelfieImage = file);
  }

  void setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _startKyc() async {
    if (_selectedDocType == null) {
      _showSnack('Please select a document type');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setStateIfMounted(() {
      _loading = true;
      _statusMessage = null;
      _kycStatus = null;
      _rejectionReason = null;
    });

    final body = jsonEncode({
      "customer_id": _customerIdController.text.trim(),
      "doc_type": _selectedDocType,
    });

    try {
      final uri = Uri.parse('$baseUrl/kyc/start');
      final resp = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setStateIfMounted(() {
          _kycId = data['kyc_id'] ?? data['id'] ?? 'N/A';
          _currentStep = KycStep.uploadDoc;
          _statusMessage = data['message'] ?? 'KYC started';
        });
        _showSnack('KYC started (ID: $_kycId)');
      } else {
        String msg = 'Error: ${resp.statusCode}';
        try {
          final data = jsonDecode(resp.body);
          msg = data['detail'] ?? data['message'] ?? resp.body;
        } catch (_) {}
        _showSnack(msg, color: Colors.redAccent);
      }
    } catch (e) {
      _showSnack('Network error: $e', color: Colors.redAccent);
    } finally {
      setStateIfMounted(() => _loading = false);
    }
  }

  Future<void> _uploadFile(String pathKey, XFile file,
      {required String endpoint, Map<String, String>? extraFields}) async {
    if (_kycId == null) {
      _showSnack('KYC not started yet');
      return;
    }

    setStateIfMounted(() {
      _loading = true;
      _statusMessage = null;
    });

    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);
      request.fields['kyc_id'] = _kycId!;
      if (extraFields != null) request.fields.addAll(extraFields);
      request.files.add(await http.MultipartFile.fromPath(pathKey, file.path,
          filename: file.name));

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _showSnack(data['message'] ?? 'Uploaded successfully',
            color: Colors.green);
      } else {
        String msg = 'Upload error ${resp.statusCode}';
        try {
          final data = jsonDecode(resp.body);
          msg = data['detail'] ?? data['message'] ?? resp.body;
        } catch (_) {}
        _showSnack(msg, color: Colors.redAccent);
      }
    } catch (e) {
      _showSnack('Upload failed: $e', color: Colors.redAccent);
    } finally {
      setStateIfMounted(() => _loading = false);
    }
  }

  Future<void> _uploadDocument() async {
    if (_kycId == null) return _showSnack('KYC not started yet');
    if (_docImage == null)
      return _showSnack('Please capture the document image');
    if (_docNumberController.text.trim().isEmpty)
      return _showSnack('Enter document number');

    await _uploadFile('file', _docImage!,
        endpoint: '/kyc/upload-document',
        extraFields: {'doc_number': _docNumberController.text.trim()});

    // move to next step if upload succeeded (simple optimistic UX)
    if (!mounted) return;
    setState(() {
      _currentStep = KycStep.uploadSelfie;
    });
  }

  Future<void> _uploadSelfie() async {
    if (_kycId == null) return _showSnack('KYC not started yet');
    if (_selfieImage == null) return _showSnack('Please capture a selfie');

    await _uploadFile('file', _selfieImage!, endpoint: '/kyc/upload-selfie');
    if (!mounted) return;
    setState(() {
      _currentStep = KycStep.uploadLiveSelfie;
    });
  }

  Future<void> _uploadLiveSelfie() async {
    if (_kycId == null) return _showSnack('KYC not started yet');
    if (_liveSelfieImage == null)
      return _showSnack('Please capture a live selfie');

    await _uploadFile('file', _liveSelfieImage!,
        endpoint: '/kyc/upload-live-selfie');

    if (!mounted) return;
    setState(() {
      _currentStep = KycStep.done;
      _kycStatus = 'IN_PROGRESS';
      _statusMessage = 'Submitted for verification';
    });
  }

  Future<void> _fetchStatus() async {
    if (_kycId == null) return _showSnack('No KYC ID yet');

    setStateIfMounted(() => _loading = true);

    try {
      final uri = Uri.parse('$baseUrl/kyc/status/$_kycId');
      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setStateIfMounted(() {
          _kycStatus = data['status'];
          _rejectionReason = data['rejection_reason'];
          _statusMessage = data['message'] ?? _statusMessage;
        });
      } else {
        String msg = 'Status error ${resp.statusCode}';
        try {
          final data = jsonDecode(resp.body);
          msg = data['detail'] ?? data['message'] ?? resp.body;
        } catch (_) {}
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack('Network error: $e');
    } finally {
      setStateIfMounted(() => _loading = false);
    }
  }

  // ---------- UI builders ----------

  Widget _statusChip() {
    final status = _kycStatus?.toUpperCase() ?? 'N/A';
    Color color = Colors.grey;
    if (status == 'APPROVED') color = Colors.green;
    if (status == 'REJECTED') color = Colors.red;
    if (status == 'IN_PROGRESS') color = Colors.orange;

    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.12),
      avatar: Icon(
        status == 'APPROVED'
            ? Icons.check_circle
            : status == 'REJECTED'
                ? Icons.cancel
                : Icons.hourglass_top,
        color: color,
      ),
    );
  }

  Widget _buildTopProgress() {
    final stepIndex = _currentStep.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Digital KYC Journey',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Step ${stepIndex + 1} of ${KycStep.values.length}',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
            _statusChip(),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: (stepIndex + 1) / (KycStep.values.length),
            minHeight: 10,
            backgroundColor: Colors.indigo.withOpacity(0.08),
          ),
        ),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF5B7BFF), Color(0xFF7BD6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Verify in minutes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'Scan documents, snap selfies, and track status with a guided flow.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 88,
            width: 88,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                const Icon(Icons.verified_user, color: Colors.white, size: 52),
          )
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  Widget _previewTile(String title, XFile? file) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFF0F2F8),
        ),
        child: file == null
            ? const Icon(Icons.insert_drive_file, color: Colors.black54)
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(file.path), fit: BoxFit.cover),
              ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: file == null ? const Text('No image yet') : Text(file.name),
      trailing: file == null
          ? null
          : const Icon(Icons.check_circle, color: Colors.green),
    );
  }

  Widget _buildSelectDocStep() {
    return Form(
      key: _formKey,
      child: _sectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Start verification',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerIdController,
              decoration: const InputDecoration(labelText: 'Customer ID'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter Customer ID' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedDocType,
              items: const [
                DropdownMenuItem(value: 'AADHAAR', child: Text('Aadhaar Card')),
                DropdownMenuItem(value: 'PAN', child: Text('PAN Card')),
                DropdownMenuItem(value: 'VOTER_ID', child: Text('Voter ID')),
                DropdownMenuItem(value: 'PASSPORT', child: Text('Passport')),
              ],
              onChanged: (val) =>
                  setStateIfMounted(() => _selectedDocType = val),
              validator: (v) => v == null ? 'Please select a document' : null,
              decoration:
                  const InputDecoration(labelText: 'Select KYC Document Type'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _startKyc,
                icon: const Icon(Icons.rocket_launch),
                label: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Start KYC'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadDocStep() {
    return SingleChildScrollView(
      child: _sectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step 2: Scan & Upload Document',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _docNumberController,
              decoration: const InputDecoration(labelText: 'Document Number'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _pickImageForDoc,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan Document'),
                ),
                const SizedBox(width: 12),
                Expanded(child: _previewTile('Document', _docImage)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _uploadDocument,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Upload Document'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setStateIfMounted(() {
                            _currentStep = KycStep.selectDoc;
                          });
                        },
                  child: const Text('Back'),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSelfieStep() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 3: Upload Selfie',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                  onPressed: _loading ? null : _pickSelfie,
                  icon: const Icon(Icons.camera_front),
                  label: const Text('Capture Selfie')),
              const SizedBox(width: 12),
              Expanded(child: _previewTile('Selfie', _selfieImage)),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: FilledButton(
                    onPressed: _loading ? null : _uploadSelfie,
                    child: const Text('Upload Selfie'))),
            const SizedBox(width: 12),
            OutlinedButton(
                onPressed: _loading
                    ? null
                    : () => setStateIfMounted(
                        () => _currentStep = KycStep.uploadDoc),
                child: const Text('Back'))
          ])
        ],
      ),
    );
  }

  Widget _buildUploadLiveSelfieStep() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 4: Upload Live Selfie',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton.icon(
                onPressed: _loading ? null : _pickLiveSelfie,
                icon: const Icon(Icons.videocam),
                label: const Text('Capture Live Selfie')),
            const SizedBox(width: 12),
            Expanded(child: _previewTile('Live Selfie', _liveSelfieImage)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: FilledButton(
                    onPressed: _loading ? null : _uploadLiveSelfie,
                    child: const Text('Upload & Complete KYC'))),
            const SizedBox(width: 12),
            OutlinedButton(
                onPressed: _loading
                    ? null
                    : () => setStateIfMounted(
                        () => _currentStep = KycStep.uploadSelfie),
                child: const Text('Back'))
          ])
        ],
      ),
    );
  }

  Widget _buildDoneStep() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('KYC Status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            color: Colors.indigo.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('KYC ID: ${_kycId ?? "-"}'),
                          _statusChip()
                        ]),
                    const SizedBox(height: 8),
                    if (_statusMessage != null) Text(_statusMessage!),
                    if (_rejectionReason != null) ...[
                      const SizedBox(height: 8),
                      Text('Reason: $_rejectionReason',
                          style: const TextStyle(color: Colors.red)),
                    ]
                  ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton.icon(
                onPressed: _loading ? null : _fetchStatus,
                icon: const Icon(Icons.refresh),
                label: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Refresh Status')),
            const SizedBox(width: 12),
            OutlinedButton(
                onPressed: _loading
                    ? null
                    : () {
                        setStateIfMounted(() {
                          _currentStep = KycStep.selectDoc;
                          _kycId = null;
                          _docImage = null;
                          _selfieImage = null;
                          _liveSelfieImage = null;
                          _kycStatus = null;
                          _rejectionReason = null;
                        });
                      },
                child: const Text('Start New KYC'))
          ])
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    switch (_currentStep) {
      case KycStep.selectDoc:
        body = _buildSelectDocStep();
        break;
      case KycStep.uploadDoc:
        body = _buildUploadDocStep();
        break;
      case KycStep.uploadSelfie:
        body = _buildUploadSelfieStep();
        break;
      case KycStep.uploadLiveSelfie:
        body = _buildUploadLiveSelfieStep();
        break;
      case KycStep.done:
        body = _buildDoneStep();
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital KYC Flow'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildTopProgress(),
              const SizedBox(height: 12),
              _heroCard(),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: SingleChildScrollView(
                      key: ValueKey(_currentStep), child: body),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
