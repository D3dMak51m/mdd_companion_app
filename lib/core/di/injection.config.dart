// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart'
    as _i161;

import '../../data/datasources/local/auth_local_datasource.dart' as _i17;
import '../../data/datasources/remote/auth_remote_datasource.dart' as _i1057;
import '../../data/repositories/auth_repository_impl.dart' as _i895;
import '../../data/repositories/sos_repository_impl.dart' as _i853;
import '../../domain/repositories/auth_repository.dart' as _i1073;
import '../../domain/repositories/incident_repository.dart' as _i333;
import '../../domain/repositories/sos_repository.dart' as _i585;
import '../../presentation/bloc/auth/auth_bloc.dart' as _i605;
import '../../presentation/bloc/incident/incident_bloc.dart' as _i105;
import '../../repositories/incident_repository_impl.dart' as _i331;
import '../network/dio_client.dart' as _i667;
import '../services/background_service.dart' as _i879;
import '../services/ble_service.dart' as _i1019;
import '../services/location_service.dart' as _i669;
import '../services/notification_service.dart' as _i941;
import 'register_module.dart' as _i291;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    final networkModule = _$NetworkModule();
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => registerModule.secureStorage,
    );
    gh.lazySingleton<_i161.InternetConnection>(
      () => registerModule.internetConnection,
    );
    gh.lazySingleton<_i879.AppBackgroundService>(
      () => _i879.AppBackgroundService(),
    );
    gh.lazySingleton<_i1019.BleService>(() => _i1019.BleService());
    gh.lazySingleton<_i669.LocationService>(() => _i669.LocationService());
    gh.lazySingleton<_i941.NotificationService>(
      () => _i941.NotificationService(),
    );
    gh.lazySingleton<_i17.AuthLocalDataSource>(
      () => _i17.AuthLocalDataSourceImpl(gh<_i558.FlutterSecureStorage>()),
    );
    gh.lazySingleton<_i361.Dio>(
      () => networkModule.dio(gh<_i17.AuthLocalDataSource>()),
    );
    gh.lazySingleton<_i333.IncidentRepository>(
      () => _i331.IncidentRepositoryImpl(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i585.SosRepository>(
      () => _i853.SosRepositoryImpl(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i1057.AuthRemoteDataSource>(
      () => _i1057.AuthRemoteDataSourceImpl(gh<_i361.Dio>()),
    );
    gh.factory<_i105.IncidentBloc>(
      () => _i105.IncidentBloc(gh<_i333.IncidentRepository>()),
    );
    gh.lazySingleton<_i1073.AuthRepository>(
      () => _i895.AuthRepositoryImpl(
        gh<_i1057.AuthRemoteDataSource>(),
        gh<_i17.AuthLocalDataSource>(),
      ),
    );
    gh.factory<_i605.AuthBloc>(
      () => _i605.AuthBloc(gh<_i1073.AuthRepository>()),
    );
    return this;
  }
}

class _$RegisterModule extends _i291.RegisterModule {}

class _$NetworkModule extends _i667.NetworkModule {}
