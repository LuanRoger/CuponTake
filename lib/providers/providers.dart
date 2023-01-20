import 'package:cupon_take/models/cupon.dart';
import 'package:cupon_take/models/cupon_redeem.dart';
import 'package:cupon_take/models/enums/http_codes.dart';
import 'package:cupon_take/models/exceptions/empty_list_exception.dart';
import 'package:cupon_take/models/exceptions/http_not_succeed_exception.dart';
import 'package:cupon_take/models/exceptions/no_auth_key_exception.dart';
import 'package:cupon_take/models/http_response.dart';
import 'package:cupon_take/models/redeem_history_http_request.dart';
import 'package:cupon_take/models/theme_preferences.dart';
import 'package:cupon_take/models/user_info.dart';
import 'package:cupon_take/providers/interfaces/theme_preferences_state.dart';
import 'package:cupon_take/services/auth_service.dart';
import 'package:cupon_take/services/cupon_services.dart';
import 'package:cupon_take/shared/preferences/global_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'interfaces/user_auth_state.dart';

late final ChangeNotifierProvider<GlobalPreferences> preferencesProvider;

final userAuthProvider =
    StateNotifierProvider<UserAuthKeyState, String?>((ref) {
  final userAuthKeyProvider = ref.watch(preferencesProvider);

  return UserAuthKeyState(authKey: userAuthKeyProvider.cupontakeAuthKey);
});

final themePreferencesProvider =
    StateNotifierProvider<ThemePreferencesState, ThemePreferences>((ref) {
  final preferences = ref.watch(preferencesProvider
      .select((value) => value.preferences.themePreferences));

  return ThemePreferencesState(
    ThemePreferences(
        brightness: preferences.brightness, colorIndex: preferences.colorIndex),
  );
});

final fetchUserInfoProvider = FutureProvider<UserInfo>((ref) async {
  final userAuthKey = ref.watch(userAuthProvider);

  if (userAuthKey == null || userAuthKey.isEmpty) {
    throw NoAuthException();
  }

  AuthServices authServices = AuthServices();
  HttpResponse response = await authServices.getUserInfo(userAuthKey);
  if (response.statusCode != HttpCodes.SUCCESS.code) {
    throw HttpNotSucceedException("getUserInfo", code: response.statusCode);
  }

  return UserInfo(response.body["username"] as String,
      points: response.body["points"] as int);
});

final fetchUserRedeemHistoryProvider =
    FutureProvider.family<List<CuponRedeem>, RedeemHistoryHttpRequest>(
        (ref, requestInfo) async {
  final userAuthKey = ref.watch(userAuthProvider);

  if (userAuthKey == null || userAuthKey.isEmpty) {
    throw NoAuthException();
  }

  CuponServices cuponServices = CuponServices();
  final response =
      await cuponServices.getRedeemHistory(userAuthKey, requestInfo);
  if (response.statusCode != HttpCodes.SUCCESS.code) {
    throw HttpNotSucceedException("getRedeemHistory",
        code: response.statusCode);
  }

  List<CuponRedeem> history = List.empty(growable: true);
  for (var cupon in response.body as List<dynamic>) {
    history.add(
      CuponRedeem(
        redeemProtocol: cupon["redeemProtocol"],
        cupon: Cupon(
          cuponCode: cupon["redeemCupon"]["cuponCode"],
          createdAt: DateTime.parse(cupon["redeemCupon"]["createdAt"]),
        ),
      ),
    );
  }
  if (history.isEmpty) throw EmptyListExceeption();

  return history;
});
