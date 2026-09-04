import 'package:flutter/material.dart';

import 'profile_widgets.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> faqs = [
      {
        'q': 'How is the final trade-in price determined?',
        'a': 'Our price algorithm evaluates your phone model, screen condition, physical body wear, functional hardware checks, and device age.'
      },
      {
        'q': 'When do I get paid for selling my device?',
        'a': 'You receive payment instantly via UPI, IMPS bank transfer, or store gift card right after our field executive inspects your device at pickup.'
      },
      {
        'q': 'Do I need to carry original accessories & box?',
        'a': 'Original charger and box add extra trade-in value to your device, but they are not mandatory to complete the transaction.'
      },
      {
        'q': 'Is it safe to trade in my old phone?',
        'a': 'Yes, completely safe! We perform a factory data wipe verification at pickup to ensure your personal data is 100% secure.'
      },
    ];

    return Scaffold(
      backgroundColor: kProfileSurface,
      appBar: AppBar(
        backgroundColor: kProfilePrimaryTheme,
        elevation: 0,
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kProfilePrimaryTheme,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'How can we help you?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'We are available Mon - Sun from 9:00 AM to 8:00 PM',
                    style: TextStyle(color: Color(0xFFFFCDD2), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildContactTile(
                  icon: Icons.call,
                  label: 'Call Us',
                  subtitle: '+91 1800 123 4567',
                  color: Colors.green.shade700,
                  onTap: () {},
                ),
                const SizedBox(width: 12),
                _buildContactTile(
                  icon: Icons.chat,
                  label: 'WhatsApp Chat',
                  subtitle: 'Instant Help',
                  color: Colors.teal.shade700,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kProfileBorder),
              ),
              child: Column(
                children: faqs.map((faq) {
                  return ExpansionTile(
                    shape: const Border(),
                    leading: const Icon(Icons.help_outline, color: kProfilePrimaryTheme, size: 20),
                    title: Text(
                      faq['q']!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                        child: Text(
                          faq['a']!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kProfileBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
