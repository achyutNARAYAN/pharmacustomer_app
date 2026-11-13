import 'package:flutter/material.dart';

import '../../core/theme.dart';

class ClinicalSupport extends StatefulWidget {
  const ClinicalSupport({super.key});

  @override
  State<ClinicalSupport> createState() => _ClinicalSupportState();
}

class _ClinicalSupportState extends State<ClinicalSupport> {
  final _input = TextEditingController();
  final _messages = <_Message>[
    const _Message(
      'Hello! I am your PharmaCustomer clinical liaison. A registered pharmacist is available to assist you with medication queries and dosage instructions.',
      false, 
    ),
    const _Message(
      'Should I take my prescribed medicine with meals or on an empty stomach?',
      true,
    ),
    const _Message(
      'Thanks for checking. Please follow the directions on your prescription label. I can connect you directly with an on-duty pharmacist for personalized dosage guidance.',
      false,
      guidance: true,
    ),
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackButton(),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pharmaCustomer Clinical Support'),
          Text(
            '● Online · Lead Pharmacist on Duty',
            style: TextStyle(fontSize: 11, color: AppTheme.primary),
          ),
        ],
      ),
      actions: [
        IconButton(onPressed: _about, icon: const Icon(Icons.info_outline)),
        IconButton(
          onPressed: () => _snack('Order #AC-884920'),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
      ],
    ),
    body: Column(
      children: [
        _doctorCard(),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
          child: Align(
            alignment: Alignment.center,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLow,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'FAST CLINICAL TRIAGE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: .6,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.mutedText,
                  ),
                ),
              ),
              Text(
                'Tap to ask',
                style: TextStyle(fontSize: 11, color: AppTheme.primaryDark),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _quick(
                '▣  Inquire about Dosage',
                'Please clarify the directions on my prescription.',
              ),
              _quick(
                '🌡  Report Temperature Breach',
                'I am concerned about the parcel temperature.',
              ),
              _quick(
                '↻  Refill Question',
                'I have a question about my refill.',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            itemCount: _messages.length,
            itemBuilder: (context, index) => _messageBubble(_messages[index]),
          ),
        ),
        _composer(),
      ],
    ),
  );

  Widget _doctorCard() => Container(
    margin: const EdgeInsets.fromLTRB(18, 4, 18, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.outlineBorder),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppTheme.surfaceLow,
          child: Icon(Icons.medical_services_outlined, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clinical Support Pharmacist',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Registered Pharmacy Consultant',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _snack('Connecting to the on-duty pharmacist'),
          child: const Text('Call'),
        ),
      ],
    ),
  );

  Widget _quick(String label, String message) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: () => _send(message),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    ),
  );

  Widget _messageBubble(_Message message) => Align(
    alignment: message.fromPatient
        ? Alignment.centerRight
        : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .84,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: message.fromPatient ? AppTheme.primaryDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: message.fromPatient
            ? null
            : Border.all(color: AppTheme.outlineBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.guidance)
            const Text(
              'Clinical Guidance · Dapavel 10mg',
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          Text(
            message.text,
            style: TextStyle(
              color: message.fromPatient ? Colors.white : AppTheme.text,
              height: 1.4,
            ),
          ),
          if (message.guidance) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'For advice tailored to your medication and health history, please follow your prescription label or ask the pharmacist on duty.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => _snack('Thanks for your feedback'),
                  child: const Text('Yes, thank you'),
                ),
                TextButton(
                  onPressed: () => _snack('A pharmacist will follow up'),
                  child: const Text('Need more help'),
                ),
              ],
            ),
          ],
          if (!message.fromPatient)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                message.guidance
                    ? 'Clinical Pharmacist'
                    : 'PharmaCustomer Assistant',
                style: const TextStyle(fontSize: 10, color: AppTheme.mutedText),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _composer() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: AppTheme.error, size: 12),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Immediate Clinical Escalation Available',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _snack('Calling the on-duty pharmacist'),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('Call Pharmacist'),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    _snack('Document attachment will be enabled in next release'),
                icon: const Icon(Icons.attach_file),
              ),
              IconButton(
                onPressed: () => _snack('Camera access will be enabled in next release'),
                icon: const Icon(Icons.camera_alt_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(_input.text),
                  decoration: const InputDecoration(
                    hintText: 'Type clinical question',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    _snack('Voice notes will be enabled in next release'),
                icon: const Icon(Icons.mic_none),
              ),
              IconButton.filled(
                onPressed: () => _send(_input.text),
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void _send(String text) {
    final value = text.trim();
    if (value.isEmpty) return;
    setState(() {
      _messages.add(_Message(value, true));
      _input.clear();
      _messages.add(
        const _Message(
          'Thanks for your message. I have alerted the on-duty pharmacist, who will respond here shortly.',
          false,
        ),
      );
    });
  }

  void _about() => showDialog<void>(
    context: context,
    builder: (_) => const AlertDialog(
      title: Text('Secure clinical support'),
      content: Text(
        'This demo chat does not send messages. For urgent symptoms, contact local emergency services or your care team.',
      ),
    ),
  );
  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _Message {
  const _Message(
    this.text,
    this.fromPatient, {
    this.guidance = false,
  });
  final String text;
  final bool fromPatient;
  final bool guidance;
}
