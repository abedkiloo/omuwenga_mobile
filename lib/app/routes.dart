abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const changePassword = '/change-password';
  static const health = '/health';
  /// About / version — shop-floor app info (replaces bare “API health”).
  static const about = '/about';
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
  static const dailyNotes = '/daily-notes';
  static const appraisals = '/appraisals';
  static const payroll = '/payroll';
  static const approvals = '/approvals';
  static const expenses = '/expenses';

  static String posForSale(int saleId) => '$pos?sale=$saleId';

  static String customerDetail(int id, {String? tab}) {
    final path = '/customers/$id';
    if (tab == null || tab.isEmpty) return path;
    return '$path?tab=${Uri.encodeQueryComponent(tab)}';
  }
  static String customerEdit(int id) => '/customers/$id/edit';
  static String customerSettle(int id) => '/customers/$id/settle';
  static String saleDetail(int id) => '/sales/$id';
  static String paymentDetail(int id) => '/payments/$id';
  static String dailyCustomerDay(int customerId, {required String date}) =>
      '/daily-sales/customer/$customerId?date=${Uri.encodeQueryComponent(date)}';
  static String fieldOrderCartForSite(int siteId) => '/visit-orders/new';
  static String dispatchOrder(int id) => '/dispatch/orders/$id';
  static String deliveryStop(int id) => '/delivery/stops/$id';
}
