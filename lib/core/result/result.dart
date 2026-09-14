/// Lightweight Result / Either for domain + network boundaries.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(Object error, StackTrace? stackTrace) failure,
  }) {
    final self = this;
    return switch (self) {
      Success<T>(:final value) => success(value),
      Failure<T>(:final error, :final stackTrace) => failure(error, stackTrace),
    };
  }

  Result<R> map<R>(R Function(T value) transform) {
    return when(
      success: (value) => Success(transform(value)),
      failure: Failure.new,
    );
  }

  T getOrThrow() {
    return when(
      success: (value) => value,
      failure: (error, stackTrace) {
        if (stackTrace != null) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        throw error;
      },
    );
  }

  T? getOrNull() {
    return when(success: (value) => value, failure: (_, _) => null);
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}
