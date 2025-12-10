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
  State<KycFlowPage> createState() => KycFlowPageState();
}

// ... (The code before KycFlowPage remains the same)

class KycFlowPageState extends State<KycFlowPage> {
  late KycStep _currentStep;
  late TextEditingController _customerIdController;
  late TextEditingController _docNumberController;
  late String _selectedDocType;
  late XFile? _docImage;
  late XFile? _selfieImage;
  late XFile? _liveSelfieImage;
  late bool _loading;
  late GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _currentStep = KycStep.selectDoc;
    _customerIdController = TextEditingController();
    _docNumberController = TextEditingController();
    _selectedDocType = 'AADHAAR';
    _docImage = null;
    _selfieImage = null;
    _liveSelfieImage = null;
    _loading = false;
    _formKey = GlobalKey<FormState>();
  }

  @override
  void dispose() {
    _customerIdController.dispose();
    _docNumberController.dispose();
    super.dispose();
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _showSnack(String msg, [bool error = false]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _pickImageForDoc() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    setStateIfMounted(() => _docImage = file);
  }

  Future<void> _pickSelfie() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    setStateIfMounted(() => _selfieImage = file);
  }

  Future<void> _pickLiveSelfie() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    setStateIfMounted(() => _liveSelfieImage = file);
  }

  Future<void> _startKyc() async {
    if (_selectedDocType == null) {
      _showSnack('Please select a document type');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setStateIfMounted(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/kyc/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customer_id': _customerIdController.text,
          'doc_type': _selectedDocType
        }),
      );
      if (response.statusCode == 200) {
        setStateIfMounted(() => _currentStep = KycStep.uploadDoc);
        _showSnack('KYC started successfully');
      } else {
        _showSnack('Failed to start KYC', true);
      }
    } catch (e) {
      _showSnack('Error: $e', true);
    } finally {
      setStateIfMounted(() => _loading = false);
    }
  }

  Future<void> _uploadDocument() async {
    if (_docImage == null) {
      _showSnack('Please capture document image', true);
      return;
    }
    setStateIfMounted(() => _loading = true);
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/kyc/upload_document'))
        ..files
            .add(await http.MultipartFile.fromPath('document', _docImage!.path))
        ..fields['customer_id'] = _customerIdController.text
        ..fields['doc_number'] = _docNumberController.text;

      final response = await request.send();
      if (response.statusCode == 200) {
        setStateIfMounted(() => _currentStep = KycStep.uploadSelfie);
        _showSnack('Document uploaded successfully');
      } else {
        _showSnack('Failed to upload document', true);
      }
    } catch (e) {
      _showSnack('Error: $e', true);
    } finally {
      setStateIfMounted(() => _loading = false);
    }
  }

  Future<void> _uploadSelfie() async {
    if (_selfieImage == null) {
      _showSnack('Please capture selfie', true);
      return;
    }
    setStateIfMounted(() => _loading = true);
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/kyc/upload_selfie'))
            ..files.add(
                await http.MultipartFile.fromPath('selfie', _selfieImage!.path))
            ..fields['customer_id'] = _customerIdController.text;

      final response = await request.send();
      if (response.statusCode == 200) {
        setStateIfMounted(() => _currentStep = KycStep.uploadLiveSelfie);
        _showSnack('Selfie uploaded successfully');
      } else {
        _showSnack('Failed to upload selfie', true);
      }
    } catch (e) {
      _showSnack('Error: $e', true);
    } finally {
      setStateIfMounted(() => _loading = false);
    }
  }

  Future<void> _uploadLiveSelfie() async {
    if (_liveSelfieImage == null) {
      _showSnack('Please capture live selfie', true);
      return;
    }
    setStateIfMounted(() => _loading = true);

    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/kyc/upload_live_selfie'))
        ..files.add(await http.MultipartFile.fromPath(
            'live_selfie', _liveSelfieImage!.path))
        ..fields['customer_id'] = _customerIdController.text;

      final response = await request.send();
      if (response.statusCode == 200) {
        setStateIfMounted(() => _currentStep = KycStep.done);
        _showSnack('KYC completed successfully');
      } else {
        _showSnack('Failed to upload live selfie', true);
      }
    } catch (e) {
      _showSnack('Error: $e', true);
    } finally {
      setStateIfMounted(() => _loading = false);
    }
  }

  Widget _statusChip() {
    final statusText =
        _currentStep == KycStep.done ? 'Completed' : 'In Progress';
    return Chip(
      label: Text(statusText),
      backgroundColor: _currentStep == KycStep.done
          ? Colors.green.shade100
          : Colors.orange.shade100,
      labelStyle: TextStyle(
        color: _currentStep == KycStep.done ? Colors.green : Colors.orange,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildDoneStep() {
    return _sectionCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text('KYC Verification Complete!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Your identity has been successfully verified.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setStateIfMounted(() {
              _currentStep = KycStep.selectDoc;
              _customerIdController.clear();
              _docNumberController.clear();
              _docImage = null;
              _selfieImage = null;
              _liveSelfieImage = null;
            }),
            child: const Text('Start New KYC'),
          ),
        ],
      ),
    );
  }

  // New map for step details and icons
  final Map<KycStep, Map<String, dynamic>> _stepDetails = {
    KycStep.selectDoc: {
      'title': '1. Select Document',
      'icon': Icons.description_rounded,
    },
    KycStep.uploadDoc: {
      'title': '2. Scan Document',
      'icon': Icons.camera_alt_rounded,
    },
    KycStep.uploadSelfie: {
      'title': '3. Upload Selfie',
      'icon': Icons.face_retouching_natural_rounded,
    },
    KycStep.uploadLiveSelfie: {
      'title': '4. Live Liveness Check',
      'icon': Icons.video_call_rounded,
    },
    KycStep.done: {
      'title': '5. Verification Complete',
      'icon': Icons.check_circle_outline_rounded,
    },
  };

  // ... (Existing helper methods like _showSnack, _pick, setStateIfMounted, and API methods)

  // --- Start of modified UI builders ---

  // 1. New Custom Step Indicator Widget
  Widget _stepIndicator(KycStep step, int index) {
    final bool isActive = step == _currentStep;
    final bool isDone = step.index < _currentStep.index;
    final iconData = _stepDetails[step]!['icon'] as IconData;
    final String title = _stepDetails[step]!['title'] as String;
    final Color color = isDone
        ? Colors.green.shade600
        : isActive
            ? Colors.indigo
            : Colors.grey.shade400;

    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.15),
            child: isDone
                ? Icon(Icons.check, size: 20, color: color)
                : Icon(iconData, size: 20, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title.split('. ')[1], // Use only the main part of the title
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.indigo.shade900 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // 2. Refactored Top Progress Bar
  @override
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
                Text(
                    '${_stepDetails[_currentStep]!['title']}', // Show current step title
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
            _statusChip(),
          ],
        ),
        const SizedBox(height: 12),
        // Custom Step-by-Step Indicator
        Row(
          children: KycStep.values
              .map((step) => _stepIndicator(step, step.index))
              .toList(),
        ),
        // Divider line between steps (can be removed if step circles are enough)
        // const Divider(),
      ],
    );
  }

  // 3. Image Preview Enhancements
  Widget _previewTile(String title, XFile? file) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: file == null
                ? Colors.indigo.withOpacity(0.08)
                : Colors.grey.shade200,
            border: Border.all(
              color:
                  file == null ? Colors.indigo.withOpacity(0.3) : Colors.green,
              width: file == null ? 1 : 2,
            ),
          ),
          child: file == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image_search,
                        color: Colors.black45, size: 40),
                    const SizedBox(height: 8),
                    Text('No image selected',
                        style: TextStyle(color: Colors.black54)),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(file.path),
                    fit: BoxFit.cover,
                    //  // Image Tag for the user's view
                  ),
                ),
        ),
        if (file != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Captured: ${file.name}',
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
      ],
    );
  }

  // 4. Step Specific UI Overhauls

  @override
  Widget _buildSelectDocStep() {
    return Form(
      key: _formKey,
      child: _sectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Start Verification',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Enter your Customer ID and select the document you wish to use for KYC verification.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            // ... (TextFormField and DropdownButtonFormField remain the same)

            TextFormField(
              controller: _customerIdController,
              decoration: const InputDecoration(
                labelText: 'Customer ID',
                prefixIcon: Icon(Icons.person_outline),
              ),
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
              onChanged: (val) {
                if (val != null) {
                  setStateIfMounted(() => _selectedDocType = val);
                }
              },
              validator: (v) => v == null ? 'Please select a document' : null,
              decoration: const InputDecoration(
                labelText: 'Select KYC Document Type',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),

            // ... (Rest of the widget remains the same until the end)
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _startKyc,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Start KYC'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget _buildUploadDocStep() {
    return SingleChildScrollView(
      child: _sectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scan & Upload Document',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Upload a clear, non-blurry image of your selected ${_selectedDocType ?? 'document'}.',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _docNumberController,
              decoration: const InputDecoration(
                  labelText: 'Document Number',
                  prefixIcon: Icon(Icons.numbers_outlined)),
            ),
            const SizedBox(height: 20),

            // Document Preview and Picker
            _previewTile('Document Image Preview', _docImage
                //  // Image Tag for best practice
                ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _pickImageForDoc,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture Document Image'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 24),
            // Navigation Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _uploadDocument,
                    child: _loading
                        ? const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)
                        : const Text('Upload & Continue'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
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
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget _buildUploadSelfieStep() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload Reference Selfie',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Capture a clear, recent, frontal photo of your face for reference. No hats or sunglasses.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),

          // Selfie Preview and Picker
          _previewTile('Selfie Preview', _selfieImage
              //  // Image Tag for best practice
              ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _pickSelfie,
              icon: const Icon(Icons.camera_front),
              label: const Text('Capture Reference Selfie'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.indigo.shade400,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 24),
          // Navigation Buttons
          Row(children: [
            Expanded(
                child: FilledButton(
              onPressed: _loading ? null : _uploadSelfie,
              child: const Text('Upload & Continue'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _loading
                  ? null
                  : () =>
                      setStateIfMounted(() => _currentStep = KycStep.uploadDoc),
              child: const Text('Back'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            )
          ])
        ],
      ),
    );
  }

  @override
  Widget _buildUploadLiveSelfieStep() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live Liveness Check (Anti-Fraud)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Capture a "live" selfie or short video to prove you are a real person. Follow any prompts your camera gives.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),

          // Live Selfie Preview and Picker
          _previewTile('Live Selfie/Video Preview', _liveSelfieImage
              //  // Image Tag for best practice
              ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _pickLiveSelfie,
              icon: const Icon(Icons.videocam),
              label: const Text('Start Liveness Check'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.indigo.shade400,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 24),
          // Navigation Buttons
          Row(children: [
            Expanded(
                child: FilledButton(
              onPressed: _loading ? null : _uploadLiveSelfie,
              child: const Text('Upload & Complete KYC'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _loading
                  ? null
                  : () => setStateIfMounted(
                      () => _currentStep = KycStep.uploadSelfie),
              child: const Text('Back'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            )
          ])
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital KYC Verification'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTopProgress(),
              const SizedBox(height: 24),
              if (_currentStep == KycStep.selectDoc) _buildSelectDocStep(),
              if (_currentStep == KycStep.uploadDoc) _buildUploadDocStep(),
              if (_currentStep == KycStep.uploadSelfie)
                _buildUploadSelfieStep(),
              if (_currentStep == KycStep.uploadLiveSelfie)
                _buildUploadLiveSelfieStep(),
              if (_currentStep == KycStep.done) _buildDoneStep(),
            ],
          ),
        ),
      ),
    );
  }
}
