abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const changePassword = '/change-password';
  static const health = '/health';
  static const home = '/home';
  static const pos = '/pos';
  static const customers = '/customers';
  static const customerNew = '/customers/new';
  static const debtors = '/debtors';
  static const more = '/more';
  static const dailySales = '/daily-sales';
  static const salesHistory = '/sales';
  static const siteVisit = '/visit-orders/new';
  static const fieldOrderCart = '/visit-orders/new';
  static const fieldOrderReview = '/visit-orders/review';
  static const dispatchQueue = '/dispatch';
  static const deliveryRoute = '/delivery';

  static String customerDetail(int id) => '/customers/$id';
  static String customerEdit(int id) => '/customers/$id/edit';
  static String customerSettle(int id) => '/customers/$id/settle';
  static String saleDetail(int id) => '/sales/$id';
  static String dailyCustomerDay(int customerId, {required String date}) =>
      '/daily-sales/customer/$customerId?date=${Uri.encodeQueryComponent(date)}';
  static String fieldOrderCartForSite(int siteId) => '/visit-orders/new';
  static String dispatchOrder(int id) => '/dispatch/orders/$id';
  static String deliveryStop(int id) => '/delivery/stops/$id';
}
