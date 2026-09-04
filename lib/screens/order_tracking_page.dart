import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase/catalog_firebase.dart';

class OrderTrackingPage extends StatefulWidget {
  final String orderId;

  const OrderTrackingPage({super.key, required this.orderId});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          'Track Sell Order',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: catalogFirestore.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order not found'));
          }

          final d = snapshot.data!.data()!;

          String? status = d['status'] as String?;
          int currentStep = 1;
          switch (status) {
            case 'placed':
              currentStep = 1;
              break;
            case 'agent_assigned':
              currentStep = 2;
              break;
            case 'inspection':
              currentStep = 3;
              break;
            case 'paid':
              currentStep = 4;
              break;
            default:
              currentStep = 1;
          }

          final modelName = (d['modelName'] as String?) ?? '';
          final storage = (d['storage'] as String?) ?? '';
          final finalPayout = (d['finalPayout'] is num) ? (d['finalPayout'] as num).toInt() : int.tryParse('${d['finalPayout']}') ?? 0;
          final addressFull = (d['addressFullText'] as String?) ?? '';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Order Placed Successfully!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                  Text(
                                    'Order ID: ${widget.orderId}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Order Progress',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                _buildStepCircle(1, Icons.check, 'Order\nPlaced', currentStep),
                                _buildLine(1, currentStep),
                                _buildStepCircle(2, Icons.person_outline, 'Agent\nAssigned', currentStep),
                                _buildLine(2, currentStep),
                                _buildStepCircle(3, Icons.search, 'Doorstep\nInspection', currentStep),
                                _buildLine(3, currentStep),
                                _buildStepCircle(4, Icons.payments_outlined, 'Instant\nPayout', currentStep),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pickup Overview',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(Icons.phone_android, 'Device', '$modelName ($storage)'),
                            const SizedBox(height: 8),
                            _buildDetailRow(Icons.location_on_outlined, 'Pickup Address', addressFull),
                            const SizedBox(height: 8),
                            _buildDetailRow(Icons.account_balance_wallet_outlined, 'Final Amount', '₹$finalPayout'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      icon: const Icon(Icons.home_outlined, color: Color(0xFFE91E63)),
                      label: const Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepCircle(int stepNumber, IconData icon, String label, int currentStep) {
    bool isDone = stepNumber <= currentStep;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9),
              border: Border.all(
                color: isDone ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isDone ? Colors.white : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              height: 1.2,
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
              color: isDone ? const Color(0xFF16A34A) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLine(int stepNumber, int currentStep) {
    bool isDone = stepNumber < currentStep;
    return Container(
      width: 16,
      height: 3,
      margin: const EdgeInsets.only(bottom: 24),
      color: isDone ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 10),
        Text(
          '$title: ',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
