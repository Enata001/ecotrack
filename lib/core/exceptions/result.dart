class AppException implements Exception {
  final String message;
  final String? code;

  AppException({required this.message, this.code});

  @override
  String toString() => message;
}

sealed class Result<T> {
  const Result();

  R map<R>({
    required R Function(T data) onSuccess,
    required R Function(AppException error) onError,
  }) {
    final self = this;
    if (self is Success<T>) return onSuccess(self.data);
    return onError((self as Failure<T>).error);
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
}
