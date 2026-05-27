import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../utils/constants.dart';

const kAdminColor = Color(0xFF00897B);

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  List<dynamic>         _recent       = [];
  Map<dynamic, dynamic> _distribution = {};
  double                _avgRating    = 0;
  int                   _total        = 0;
  bool                  _isLoading    = false;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${Constants.baseUrl}/feedbacks'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _total        = data['total']        ?? 0;
          _avgRating    = (data['avg_rating']  ?? 0).toDouble();
          _distribution = data['distribution'] ?? {};
          _recent       = data['recent']       ?? [];
        });
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load: $e',
          backgroundColor: Colors.red, colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    }
    setState(() => _isLoading = false);
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays >= 1) return '${diff.inDays}d ago';
      if (diff.inHours >= 1) return '${diff.inHours}h ago';
      return 'Just now';
    } catch (_) { return ''; }
  }

  // ✅ Single card handles both rating and review types
  Widget _reviewCard(dynamic fb) {
    final name    = (fb['user_name'] ?? 'Unknown') as String;
    final type    = fb['type'] ?? '';
    final rating  = (fb['rating'] ?? 0).toInt();
    final comment = (fb['comment'] ?? '') as String;
    final isRating = type == 'rating';
    final isReview = type == 'review' && comment.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: kAdminColor.withOpacity(0.1),
                child: Text(name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.bold, color: kAdminColor)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600,
                      fontSize: 13, color: Colors.black87))),
              // ✅ Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isRating
                      ? Colors.amber.withOpacity(0.1)
                      : kAdminColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isRating ? 'Rating' : 'Review',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isRating ? Colors.amber.shade700 : kAdminColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(_timeAgo(fb['created_at']),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            ],
          ),

          // ✅ Show stars if rating type
          if (isRating) ...[
            const SizedBox(height: 8),
            Row(children: List.generate(5, (i) => Icon(
              i < rating ? Icons.star : Icons.star_border,
              color: Colors.amber, size: 16))),
          ],

          // ✅ Show comment if review type
          if (isReview) ...[
            const SizedBox(height: 8),
            Text(comment,
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: kAdminColor,
        foregroundColor: Colors.white,
        title: const Text('Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFeedbacks),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAdminColor))
          : RefreshIndicator(
              onRefresh: _loadFeedbacks,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Ratings Summary ──
                    const Text('Ratings Summary',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                            blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_avgRating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87)),
                              Row(children: List.generate(5, (i) {
                                if (i < _avgRating.floor()) {
                                  return const Icon(Icons.star,
                                      color: Colors.amber, size: 16);
                                } else if (i < _avgRating) {
                                  return const Icon(Icons.star_half,
                                      color: Colors.amber, size: 16);
                                } else {
                                  return const Icon(Icons.star_border,
                                      color: Colors.amber, size: 16);
                                }
                              })),
                              const SizedBox(height: 4),
                              Text('$_total total',
                                  style: TextStyle(
                                      color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: List.generate(5, (i) {
                                final star = 5 - i;
                                final pct  = (_distribution[star.toString()]
                                        ?['percentage'] ?? 0).toDouble();
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      Text('$star', style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 6),
                                      Expanded(child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct / 100,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: const AlwaysStoppedAnimation(kAdminColor),
                                          minHeight: 8,
                                        ),
                                      )),
                                      const SizedBox(width: 6),
                                      Text('${pct.toInt()}%',
                                          style: const TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Recent Reviews (merged) ──
                    Row(
                      children: [
                        const Text('Recent Reviews',
                            style: TextStyle(fontSize: 18,
                                fontWeight: FontWeight.bold, color: Colors.black87)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: kAdminColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('Latest 10',
                              style: TextStyle(fontSize: 11,
                                  color: Colors.teal.shade700,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _recent.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.white,
                                borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Column(children: [
                              Icon(Icons.inbox_outlined,
                                  size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text('No reviews yet',
                                  style: TextStyle(
                                      color: Colors.grey.shade400, fontSize: 14)),
                            ])),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _recent.length,
                            itemBuilder: (_, i) => _reviewCard(_recent[i]),
                          ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}