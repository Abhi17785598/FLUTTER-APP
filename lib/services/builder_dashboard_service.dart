import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/builder_dashboard_model.dart';

class BuilderDashboardService {
  final _supabase = Supabase.instance.client;

  Future<BuilderDashboardModel> getDashboardStats(String builderId) async {
    try {
      // ===========================
      // Projects
      // ===========================

      final projects = await _supabase
          .from('builder_projects')
          .select('id,status')
          .eq('builder_id', builderId);

      final totalProjects = projects.length;

      final activeProjects = projects
          .where((e) => e['status'] == 'active')
          .length;

      final deliveredProjects = projects
          .where(
            (e) => e['status'] == 'completed' || e['status'] == 'delivered',
          )
          .length;

      // ===========================
      // Network Members
      // ===========================

      final networks = await _supabase
          .from('builder_networks')
          .select('id')
          .eq('builder_id', builderId)
          .eq('status', 'accepted');

      final networkMembers = networks.length;

      // ===========================
      // Ratings
      // ===========================

      final ratings = await _supabase
          .from('builder_ratings')
          .select('rating,rater_id')
          .eq('builder_id', builderId);

      double customerRating = 0;
      double brokerRating = 0;

      if (ratings.isNotEmpty) {
        final raterIds = ratings.map((e) => e['rater_id']).toList();

        final profiles = await _supabase
            .from('profiles')
            .select('user_id,user_type')
            .inFilter('user_id', raterIds);

        final Map<String, String> types = {};

        for (final profile in profiles) {
          types[profile['user_id']] = profile['user_type'] ?? '';
        }

        final customerRatings = <double>[];
        final brokerRatings = <double>[];

        for (final rating in ratings) {
          final type = types[rating['rater_id']] ?? '';

          final value = (rating['rating'] as num).toDouble();

          if (type == 'broker' || type == 'influencer') {
            brokerRatings.add(value);
          } else {
            customerRatings.add(value);
          }
        }

        if (customerRatings.isNotEmpty) {
          customerRating =
              customerRatings.reduce((a, b) => a + b) / customerRatings.length;
        }

        if (brokerRatings.isNotEmpty) {
          brokerRating =
              brokerRatings.reduce((a, b) => a + b) / brokerRatings.length;
        }
      }

      return BuilderDashboardModel(
        totalProjects: totalProjects,
        activeProjects: activeProjects,
        deliveredProjects: deliveredProjects,
        networkMembers: networkMembers,
        customerRating: customerRating,
        brokerRating: brokerRating,
      );
    } catch (e) {
      print("==================================");
      print("BUILDER DASHBOARD ERROR");
      print(e);
      print("==================================");

      return BuilderDashboardModel.empty();
    }
  }
}
