import '../../../app/routes.dart';
import 'daily_report.dart';

/// Navigation target for a daily-sales order row.
String dailyOrderRoute(DailyOrder order, {required String date}) {
  final customerId = order.customerId;
  if (customerId != null) {
    return AppRoutes.dailyCustomerDay(customerId, date: date);
  }
  return AppRoutes.saleDetail(order.id);
}
