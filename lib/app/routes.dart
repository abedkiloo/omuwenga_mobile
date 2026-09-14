abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const health = '/health';
  static const home = '/home';
  static const pos = '/pos';
  static const customers = '/customers';
  static const customerNew = '/customers/new';
  static const more = '/more';
  static const dailySales = '/daily-sales';
  static const salesHistory = '/sales';
  static const siteVisit = '/agents/site-visit';
  static const fieldOrderCart = '/agents/orders/new';
  static const fieldOrderReview = '/agents/orders/review';
  static const dispatchQueue = '/dispatch';
  static const deliveryRoute = '/delivery';

  static String customerDetail(int id) => '/customers/$id';
  static String customerEdit(int id) => '/customers/$id/edit';
  static String customerSettle(int id) => '/customers/$id/settle';
  static String saleDetail(int id) => '/sales/$id';
  static String dailyCustomerDay(int customerId, {required String date}) =>
      '/daily-sales/customer/$customerId?date=${Uri.encodeQueryComponent(date)}';
  static String fieldOrderCartForSite(int siteId) =>
      '/agents/orders/new?siteId=$siteId';
  static String dispatchOrder(int id) => '/dispatch/orders/$id';
  static String deliveryStop(int id) => '/delivery/stops/$id';
}
