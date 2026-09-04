import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firebase/catalog_firebase.dart';
import 'profile_widgets.dart';
import '../screens/order_tracking_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  @override
  Widget build(BuildContext context) {
    final userId = catalogAuth.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: kProfileSurface,
        appBar: AppBar(
          backgroundColor: kProfilePrimaryTheme,
          elevation: 0,
          title: const Text(
            'My Sell Orders',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('No orders yet — sell your first phone to see it here', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          ),
        ),
      );
    }

    final stream = catalogFirestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: kProfileSurface,
      appBar: AppBar(
        backgroundColor: kProfilePrimaryTheme,
        elevation: 0,
        title: const Text(
          'My Sell Orders',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No orders yet — sell your first phone to see it here', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              ),
            );
          }

          String _formatDate(Timestamp? ts) {
            if (ts == null) return '';
            final d = ts.toDate();
            const months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            return '${d.day} ${months[d.month - 1]} ${d.year}';
          }

          Color _statusColor(String? status) {
            switch (status) {
              case 'placed':
                return Colors.orange.shade700;
              case 'agent_assigned':
                return Colors.blue.shade700;
              case 'inspection':
                return Colors.purple.shade700;
              case 'paid':
                return Colors.green.shade700;
              default:
                return Colors.orange.shade700;
            }
          }

          String _statusLabel(String? status) {
            switch (status) {
              case 'placed':
                return 'Order Placed';
              case 'agent_assigned':
                return 'Agent Assigned';
              case 'inspection':
                return 'Under Inspection';
              case 'paid':
                return 'Completed & Paid';
              default:
                return 'Processing';
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final d = doc.data();
              final modelName = (d['modelName'] as String?) ?? '';
              final storage = (d['storage'] as String?) ?? '';
              final device = storage.isNotEmpty ? '$modelName ($storage)' : modelName;
              final createdAt = d['createdAt'] as Timestamp?;
              final dateStr = _formatDate(createdAt);
              final finalPayout = d['finalPayout'] is num ? (d['finalPayout'] as num).toInt() : int.tryParse('${d['finalPayout']}') ?? 0;
              final status = (d['status'] as String?) ?? '';
              final statusColor = _statusColor(status);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: kProfileBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            doc.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kProfilePrimaryTheme.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.smartphone, color: kProfilePrimaryTheme, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Date: $dateStr',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Estimated Value',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              Text(
                                '₹$finalPayout',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: kProfilePrimaryTheme,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kProfilePrimaryTheme,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => OrderTrackingPage(orderId: doc.id)),
                              );
                            },
                            icon: const Icon(Icons.track_changes, size: 16),
                            label: const Text('Track Order'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
