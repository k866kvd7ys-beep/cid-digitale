import '../services/customer_auth_service.dart';
import 'recovery_browser_path_stub.dart'
    if (dart.library.html) 'recovery_browser_path_html.dart' as platform;

bool isCustomerPasswordRecoveryLocation() {
  final path = Uri.base.path;
  return path == customerPasswordRecoveryPath ||
      path == '$customerPasswordRecoveryPath/';
}

void clearCustomerPasswordRecoveryCredentials() {
  platform.replaceBrowserPath(customerPasswordRecoveryPath);
}

void leaveCustomerPasswordRecoveryLocation() {
  platform.replaceBrowserPath('/');
}
