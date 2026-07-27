import 'package:flutter/material.dart';

class BrokerQuickActionsWidget extends StatelessWidget {
  const BrokerQuickActionsWidget({super.key});

  Widget _action(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 22,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [

              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(.12),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 18),

        Row(
          children: [

            _action(
              Icons.add_home_work_rounded,
              "Add Property",
              Colors.deepPurple,
              () {},
            ),

            const SizedBox(width: 14),

            _action(
              Icons.analytics_rounded,
              "Analytics",
              Colors.blue,
              () {},
            ),
          ],
        ),

        const SizedBox(height: 14),

        Row(
          children: [

            _action(
              Icons.people_alt_rounded,
              "Clients",
              Colors.green,
              () {},
            ),

            const SizedBox(width: 14),

            _action(
              Icons.chat_rounded,
              "Enquiries",
              Colors.orange,
              () {},
            ),
          ],
        ),
      ],
    );
  }
}