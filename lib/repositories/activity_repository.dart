import '../models/activity.dart';
import '../models/activity_item.dart';
import '../models/item.dart';
import '../models/activity_check.dart';
import '../models/activity_check_item.dart';
import '../models/activity_check_draft.dart';

abstract class ActivityRepository {
  Future<ActivityCheckDraft?> getCheckDraft({
    required String activityId,
    required String checkType,
  });

  Future<void> saveCheckDraft({
    required String activityId,
    required String checkType,
    required DateTime startedAt,
    required Map<String, String> foundMethods,
  });

  Stream<List<Activity>> watchActivities();

  Stream<List<ActivityItem>> watchActivityItems(String activityId);

  Future<Activity?> getActivity(String activityId);

  Future<Activity> addActivity(Activity activity);

  Future<Activity> addActivityWithItems({
    required Activity activity,
    required List<Item> items,
  });

  Future<ActivityItem> addItemToActivity({
    required String activityId,
    required Item item,
  });

  Future<void> updateActivity(Activity activity);

  Future<void> deleteActivity(String activityId);

  Future<void> updateActivityStatus({
    required String activityId,
    required String status,
  });

  Future<void> completeBeforeActivityCheck({
    required String activityId,
    required List<ActivityItem> activityItems,
    required Map<String, String> foundMethods,
    required DateTime startedAt,
  });

  Future<void> completeReturnCheck({
    required String activityId,
    required List<ActivityItem> activityItems,
    required Map<String, String> foundMethods,
    required DateTime startedAt,
  });

  Future<ActivityCheck?> getActivityCheckByType({
    required String activityId,
    required String type,
  });

  Future<List<ActivityCheckItem>> getActivityCheckItems({
    required String activityId,
    required String checkId,
  });
}
