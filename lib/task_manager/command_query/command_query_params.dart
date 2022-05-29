import 'dart:convert';

import '../../debug/error_handler.dart';
import '../../extensions/map_verification_tools.dart';

typedef Parameters = Map<String, ParamsModel>;
typedef ValueParser<T> = T Function(String);

class ParamsModel {
  final String name;
  final String value;
  final bool isFromResults;
  const ParamsModel({
    required this.name,
    required this.value,
    required this.isFromResults,
  });
  T extractValue<T>({
    required Map<Type, ValueParser> mappers,
    required Map<String, dynamic> results,
  }) {
    if (isFromResults) {
      return extractFromResultsTable<T>(results);
    } else {
      return extractValueUsingTypeMappers<T>(mappers);
    }
  }

  T extractValueUsingTypeMappers<T>(Map<Type, ValueParser> mappers) {
    mappers.breakOnMissingKey([T]);
    return mappers[T]!.call(value);
  }

  T extractFromResultsTable<T>(Map<String, dynamic> results) {
    final referencedObject = results[value];
    if (referencedObject == null) {
      throw ErrorHandler(
        '''

cannot find referenced object on result table for $value
result table items: ${results.keys}''',
        <ErrorType>{
          ErrorType.variableError,
          ErrorType.notFound,
        },
      );
    }
    if (referencedObject is! T) {
      throw ErrorHandler(
        '''

found result for $value but it is not of type $T
found type is ${referencedObject.runtimeType}
result table items: ${results.keys}''',
        <ErrorType>{
          ErrorType.variableError,
          ErrorType.notFound,
        },
      );
    }
    return referencedObject;
  }

  factory ParamsModel.fromString(String element) {
    final split = element.split('=');
    final key = split[0];
    var value = split[1];
    final readFromResults = value.startsWith('|') && value.endsWith('|');
    if (readFromResults) {
      value = value.substring(1, value.length - 1);
      // value = results[value].toString();
    }

    return ParamsModel(
      name: key,
      value: value,

      ///the reason is that the value is from results
      ///but we set value from results here
      ///and this flag will active command runners value parser to replace
      ///results[value] with the real value
      ///like what we did here so it will be false but in [fromMap()]
      ///we don't have access to results and command runner will do the job
      isFromResults: false,
    );
  }
  @override
  String toString() => ' $name = $value ';

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'value': value,
      'isFromResults': isFromResults,
    };
  }

  factory ParamsModel.fromMap(
    Map<String, dynamic> map,
  ) {
    map
      ..breakOnMissingKey(['name', 'value'])
      ..breakOnLengthMissMatch([2, 3]);
    // if (!map.verifyLength([2, 3]) ||
    //     !map.containsKey(
    //       'name',
    //     ) ||
    //     !map.containsKey(
    //       'value',
    //     )) {
    //   throw ErrorHandler(
    //     '''

    //     cannot find forced fields on params map or found extra values
    //     given map is : $map''',
    //     {
    //       ErrorType.variableError,
    //     },
    //   );
    // }
    return ParamsModel(
      name: map['name'],
      value: map['value'],
      isFromResults: map['isFromResults'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory ParamsModel.fromJson(
    String source,
  ) =>
      ParamsModel.fromMap(
        json.decode(source),
      );
}
