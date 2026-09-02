import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'errors.freezed.dart';

@freezed
sealed class Failure with _$Failure {
  const factory Failure.unknown(String message, [StackTrace? stackTrace]) = UnknownFailure;
  const factory Failure.notInitialized(String feature) = NotInitializedFailure;
  const factory Failure.network(String message, {int? statusCode}) = NetworkFailure;
  const factory Failure.timeout(String operation) = TimeoutFailure;
  const factory Failure.notFound(String resource, String id) = NotFoundFailure;
  const factory Failure.alreadyExists(String resource, String id) = AlreadyExistsFailure;
  const factory Failure.permissionDenied(String permission) = PermissionDeniedFailure;
  const factory Failure.storage(String message) = StorageFailure;
  const factory Failure.decoding(String message) = DecodingFailure;
  const factory Failure.validation(String message) = ValidationFailure;
  const factory Failure.extensionUnavailable(String extensionId) = ExtensionUnavailableFailure;
  const factory Failure.extensionUnhealthy(String extensionId) = ExtensionUnhealthyFailure;
  const factory Failure.noSourcesAvailable(String query) = NoSourcesAvailableFailure;
  const factory Failure.playback(String message) = PlaybackFailure;
  const factory Failure.download(String message, {String? jobId}) = DownloadFailure;
  const factory Failure.metadata(String message) = MetadataFailure;
  const factory Failure.license(String message) = LicenseFailure;
  const factory Failure.cancelled() = CancelledFailure;
}

extension FailureX on Failure {
  String get userMessage {
    return switch (this) {
      UnknownFailure(message: final m, _) => m,
      NotInitializedFailure(feature: final f) => '$f henüz hazır değil',
      NetworkFailure(message: final m, _) => 'Ağ hatası: $m',
      TimeoutFailure(operation: final o) => '$o zaman aşımına uğradı',
      NotFoundFailure(resource: final r, id: final i) => '$r bulunamadı: $i',
      AlreadyExistsFailure(resource: final r, id: final i) => '$r zaten var: $i',
      PermissionDeniedFailure(permission: final p) => '$p izni gerekli',
      StorageFailure(message: final m) => 'Depolama hatası: $m',
      DecodingFailure(message: final m) => 'Veri okunamadı: $m',
      ValidationFailure(message: final m) => 'Geçersiz veri: $m',
      ExtensionUnavailableFailure(extensionId: final id) => 'Eklenti kullanılamıyor: $id',
      ExtensionUnhealthyFailure(extensionId: final id) => 'Eklenti sağlıksız: $id',
      NoSourcesAvailableFailure(query: final q) => 'Kaynak bulunamadı: $q',
      PlaybackFailure(message: final m) => 'Oynatma hatası: $m',
      DownloadFailure(message: final m, _) => 'İndirme hatası: $m',
      MetadataFailure(message: final m) => 'Meta veri hatası: $m',
      LicenseFailure(message: final m) => 'Lisans hatası: $m',
      CancelledFailure() => 'İptal edildi',
    };
  }

  bool get isRetryable {
    return switch (this) {
      NetworkFailure(_, statusCode: final code) => code == null || code >= 500,
      TimeoutFailure(_) => true,
      ExtensionUnhealthyFailure(_) => true,
      _ => false,
    };
  }

  bool get isUserVisible => !isA<CancelledFailure>();
}

@freezed
sealed class Result<T> with _$Result<T> {
  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = FailureResult<T>;
}

extension ResultX<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T getOrThrow() {
    return switch (this) {
      Success(value: final v) => v,
      FailureResult(failure: final f) => throw f,
    };
  }

  T? getOrNull() {
    return switch (this) {
      Success(value: final v) => v,
      FailureResult(_) => null,
    };
  }

  Failure? getFailure() {
    return switch (this) {
      Success(_) => null,
      FailureResult(failure: final f) => f,
    };
  }

  Result<U> map<U>(U Function(T) transform) {
    return switch (this) {
      Success(value: final v) => Result.success(transform(v)),
      FailureResult(failure: final f) => Result.failure(f),
    };
  }

  Future<Result<U>> mapAsync<U>(Future<U> Function(T) transform) async {
    return switch (this) {
      Success(value: final v) => Result.success(await transform(v)),
      FailureResult(failure: final f) => Result.failure(f),
    };
  }

  Result<T> onFailure(void Function(Failure) handler) {
    if (this case FailureResult(failure: final f)) {
      handler(f);
    }
    return this;
  }

  Result<T> onSuccess(void Function(T) handler) {
    if (this case Success(value: final v)) {
      handler(v);
    }
    return this;
  }
}