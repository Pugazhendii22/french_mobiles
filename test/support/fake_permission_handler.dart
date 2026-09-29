// A stand-in for the permission_handler plugin.
//
// Under flutter_test there is no platform side, so every status query fails
// and the checkup cannot tell what it still needs to ask for. This reports
// whatever a test says, which is what makes the permission flow assertable at
// all — and lets the sequencing tests skip the sheet by granting everything.
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

class FakePermissionHandler extends PermissionHandlerPlatform {
  FakePermissionHandler({
    this.initial = PermissionStatus.granted,
    this.afterRequest = PermissionStatus.granted,
  });

  /// What every permission reports before anything is asked for.
  final PermissionStatus initial;

  /// What every permission reports once requested.
  final PermissionStatus afterRequest;

  /// Permissions passed to [requestPermissions], in call order. One entry per
  /// call, so a test can prove the checkup asked once rather than per test.
  final List<List<Permission>> requests = [];

  final Map<Permission, PermissionStatus> _statuses = {};

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      _statuses[permission] ?? initial;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requests.add(List.of(permissions));
    for (final permission in permissions) {
      _statuses[permission] = afterRequest;
    }
    return {for (final p in permissions) p: afterRequest};
  }

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async =>
      ServiceStatus.enabled;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> shouldShowRequestPermissionRationale(
    Permission permission,
  ) async =>
      false;
}
