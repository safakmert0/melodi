// Placeholder errors - migration in progress
class Failure {
  final String message;
  const Failure(this.message);
  String get userMessage => message;
}
class NetworkFailure extends Failure { const NetworkFailure(super.message); }
class NotFoundFailure extends Failure { const NotFoundFailure(super.message); }
class UnknownFailure extends Failure { const UnknownFailure(super.message); }
class CancelledFailure extends Failure { const CancelledFailure() : super('cancelled'); }
sealed class Result<T> {
  const Result();
  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = FailureResult<T>;
}
class Success<T> extends Result<T> { final T value; const Success(this.value); }
class FailureResult<T> extends Result<T> { final Failure failure; const FailureResult(this.failure); }
extension ResultX<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;
}
