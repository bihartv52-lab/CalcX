import 'package:calcx/features/auth/data/auth_repository.dart';
import 'package:calcx/core/services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
   @override
   Future<void> build() async {}

   Future<void> signIn({
     required String email,
     required String password,
   }) async {
     state = const AsyncLoading();
     state = await AsyncValue.guard(
       () async {
         await ref.read(authRepositoryProvider).signIn(
               email: email,
               password: password,
             );
         // Sync FCM token to DB on successful sign-in
         await NotificationService.syncToken();
       },
     );
   }

   Future<void> signUp({
     required String email,
     required String username,
     required String password,
   }) async {
     state = const AsyncLoading();
     state = await AsyncValue.guard(
       () async {
         await ref.read(authRepositoryProvider).signUp(
               email: email,
               username: username,
               password: password,
             );
         // Sync FCM token to DB on successful sign-up
         await NotificationService.syncToken();
       },
     );
   }

   Future<void> sendPasswordReset(String email) async {
     state = const AsyncLoading();
     state = await AsyncValue.guard(
       () => ref.read(authRepositoryProvider).sendPasswordReset(email),
     );
   }
}
