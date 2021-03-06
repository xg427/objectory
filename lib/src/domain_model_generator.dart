library schema_generator;

import 'dart:mirrors';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dart_style/dart_style.dart';

class Field {
  final String label;
  final String title;
  final bool logChanges;
  final int width;
  final bool tootltipsOnContent;
  final Type parentTable;
  final String parentField;
  final bool externalKey;
  final String staticValue;
  final defaultValue;
  const Field(
      {this.label: '',
      this.title: '',
      this.logChanges: true,
      this.tootltipsOnContent: false,
      this.width: 0,
      this.parentTable: null,
      this.defaultValue: null,
      this.staticValue: '',
      this.parentField: '',
      this.externalKey: false});
}

class Table {
  final bool logChanges;
  final bool isView;
  final bool cacheValues;
  final String createScript;
  final String queryString;
  final bool sessionIdsRole;
  final bool idField;
  final bool deletedField;
  final bool modifiedDateField;
  final bool modifiedTimeField;
  final bool modifiedByField;
  final int tableId;
  const Table(
      {this.logChanges: true,
      this.isView: false,
      this.createScript: '',
      this.queryString: '',
      this.idField: true,
      this.deletedField: true,
      this.modifiedDateField: true,
      this.modifiedTimeField: true,
      this.tableId: 0,
      this.modifiedByField: true,
      this.sessionIdsRole: false,
      this.cacheValues: false});
}

///<-- Metadata

/// --> Metadata

class PropertyType {
  final _value;
  const PropertyType._internal(this._value);
  String toString() => 'PropertyType.$_value';
  static const PERSISTENT_OBJECT =
  const PropertyType._internal('PERSISTENT_OBJECT');
  static const PERSISTENT_LIST =
  const PropertyType._internal('PERSISTENT_LIST');
  static const SIMPLE = const PropertyType._internal('SIMPLE');
}

class ModelGenerator {
  static const HEADER = '''
/// Warning! That file is generated. Do not edit it manually
part of domain_model;

''';

  Symbol libraryName;
  List<ClassGenerator> classGenerators = new List<ClassGenerator>();
  Map<Type, ClassMirror> classMirrors = new Map<Type, ClassMirror>();
  List<Type> _classesOrdered = [];
  final Map<Type, List> _linkedTypes = new Map<Type, List>();
  final Map<String, PropertyGenerator> fieldsMap =
  new Map<String, PropertyGenerator>();
  ModelGenerator(this.libraryName);
  StringBuffer output = new StringBuffer();
  init() {
    var lib = currentMirrorSystem().findLibrary(libraryName);
    lib.declarations.forEach((sym, dm) {
      if (dm is ClassMirror) {
        _classesOrdered.add(dm.reflectedType);
        classMirrors[dm.reflectedType] = dm;
      }
    });
  }

  generateTo(String outFileName) {
    init();
    processAll();
//    checkOutput();
    generateOutput();
    saveOuput(outFileName);
    generateJsWrapperOutput();
    saveOuput('js_$outFileName');
  }

  checkOutput() {
    var tableIdMap = <int, int>{};
    for (var each in classGenerators) {
      tableIdMap[each.table.tableId] =
          (tableIdMap[each.table.tableId] ?? 0) + 1;
    }
    for (var key in tableIdMap.keys) {
      if (key != 0) {
        if (tableIdMap[key] > 1) {
          throw new Exception('Duplicate tableId value: $key');
        }
      }
    }
  }

  generateJsWrapperOutput() {
    const JS_WRAPPER_HEADER = '''
/// Warning! That file is generated. Do not edit it manually

@JS()
library js_wrapper;
import 'package:js/js.dart';


@JS()
@anonymous
class PersistentObjectItem{
  external int get id;
  external set id(int value);
  external String get modifiedBy;
  external set modifiedBy(String value);
  external DateTime get modifiedAtDate;
  external set modifiedAtDate(DateTime value);
  external DateTime get modifiedAtTime;
  external set modifiedAtTime(DateTime value);
  external DateTime get modifiedAt;
  external set modifiedAt(DateTime value);
  external factory PersistentObjectItem ();
}


  ''';

    output = new StringBuffer();
    output.write(JS_WRAPPER_HEADER);

    classGenerators.forEach((cls) {
      generateOuputForJsWrapper(cls);
    });
  }

  void generateOutput(
      {bool header: true,
      bool persistentClasses: true,
      bool schemaClasses: false,
      bool register: true}) {
    if (header) {
      output.write(HEADER);
    }
    classGenerators.forEach((cls) {
      generateOuputForTableSchema(cls);
      if (persistentClasses) {
        generateOuputForClass(cls);
      }
    });
    if (register) {
      output.write('registerClasses(Objectory objectoryParam) {\n');
      for (Type cls in _classesOrdered) {
        var linkedTypeMap = {};
        for (List each in _linkedTypes[cls]) {
          linkedTypeMap["'${each.first}'"] = each.last;
        }

        output.write(
            '  objectoryParam.registerClass($cls,()=>new $cls(),()=>new List<$cls>(), $linkedTypeMap);\n');
      }

      output.write('}\n');
    }
  }

  void saveOuput(String fileName) {
    if (path.isRelative(fileName)) {
      var targetDir = path.dirname(path.fromUri(Platform.script));
      fileName = path.join(targetDir, path.basename(fileName));
    }
    var formatter = new DartFormatter();
    try {
      var formattedOutput = formatter.format(output.toString(), uri: fileName);
      new File(fileName).writeAsStringSync(formattedOutput);
      print('Created file: $fileName');
    } on FormatterException catch (ex) {
      print(ex);
    }
  }

  void generateOuputForClass(ClassGenerator classGenerator) {
    output.write(
        'class ${classGenerator.type} extends ${classGenerator.superClass} {\n');
    output.writeln(
        "  TableSchema get \$schema => \$${classGenerator.type}.schema;");
    classGenerator.properties.forEach(generateOuputForProperty);
    _linkedTypes[classGenerator.type] = classGenerator.properties
        .where((PropertyGenerator p) =>
    p.propertyType == PropertyType.PERSISTENT_OBJECT)
        .map((PropertyGenerator p) => [p.name, p.type])
        .toList();
    output.write('}\n\n');
  }

  void generateOuputForJsWrapper(ClassGenerator classGenerator) {
    output.write('@JS()\n@anonymous\n');
    output.write(
        'class ${classGenerator.type}Item extends ${classGenerator.superClass}Item {\n');
    output.writeln("  external factory ${classGenerator.type}Item();");
    classGenerator.properties.forEach(generateOuputForJsProperty);
    output.write('}\n\n');
  }

  void generateOuputForProperty(PropertyGenerator propertyGenerator) {
    //output.write(propertyGenerator.commentLine);
    if (propertyGenerator.propertyType == PropertyType.SIMPLE) {
      var typeStr = '${propertyGenerator.type}';
      var typeCast = '';
      if (typeStr == 'Map') {
        typeStr = 'Map<String, dynamic>';
        typeCast = 'as $typeStr';
      }

      output
          .write('  $typeStr get ${propertyGenerator.name} => '
          "getProperty('${propertyGenerator.name}') $typeCast;\n");
      output.write(
          '  set ${propertyGenerator.name} ($typeStr value) => '
              "setProperty('${propertyGenerator.name}',value);\n");
    }
    if (propertyGenerator.propertyType == PropertyType.PERSISTENT_OBJECT) {
      output.write(
          '  ${propertyGenerator.type} get ${propertyGenerator.name} => '
              "getLinkedObject('${propertyGenerator.name}', ${propertyGenerator.type});\n");

      output.write(
          '  set ${propertyGenerator.name}(${propertyGenerator.type} value) => '
              "setLinkedObject('${propertyGenerator.name}', value);\n");

//      String capitalized =
//          propertyGenerator.name.substring(0, 1).toUpperCase() +
//              propertyGenerator.name.substring(1);
//      output.write('  set${capitalized}Id(int value) => '
//          "setForeignKey('${propertyGenerator.name}',value);\n");
    }
    if (propertyGenerator.propertyType == PropertyType.PERSISTENT_LIST) {
      output.write(
          '  ${propertyGenerator.type} get ${propertyGenerator.name} => '
              "getPersistentList(${propertyGenerator.listElementType}.value('${propertyGenerator.name}'));\n");
    }
  }

  void generateOuputForJsProperty(PropertyGenerator propertyGenerator) {
    //output.write(propertyGenerator.commentLine);
    Type type = propertyGenerator.propertyType == PropertyType.SIMPLE
        ? propertyGenerator.type
        : int;
    output.write('  external $type get ${propertyGenerator.name};\n');
    output.write('  external set ${propertyGenerator.name} ($type value);\n');
  }

  void generateOuputForTableSchema(ClassGenerator classGenerator) {
    output.write('class \$${classGenerator.type} {\n');
    List<PropertyGenerator> allProperties = [];
//      schema.Fields.id,
//      schema.Fields.deleted,
//      schema.Fields.modifiedDate,
//      schema.Fields.modifiedTime
//    ].map((schema.Field fld) {
//      Field metaField = new Field(label: fld.label, title: fld.title);
//      return new PropertyGenerator()
//        ..name = fld.id
//        ..type = fld.type
//        ..field = metaField
//        ..propertyType = PropertyType.SIMPLE;
//    }).toList();
    allProperties.addAll(classGenerator.properties);

    allProperties.forEach((propertyGenerator) {
      Type fieldType =
      propertyGenerator.propertyType == PropertyType.PERSISTENT_OBJECT
          ? int
          : propertyGenerator.type;
      output.write(
          "  static Field<$fieldType> get ${propertyGenerator.name} =>\n");
      output.write(
          "      const Field<$fieldType>(id: '${propertyGenerator.name}',label: '${propertyGenerator.field.label}',title: '${propertyGenerator.field.title}',\n");

      output.write(
          "          parentTable: ${propertyGenerator.field.parentTable},parentField: '${propertyGenerator.field.parentField}',staticValue: \"${propertyGenerator.field.staticValue}\",\n");
      var defaultValue = propertyGenerator.field.defaultValue;
      if (defaultValue == null) {
        if (propertyGenerator.type == bool) {
          defaultValue = false;
        } else if (propertyGenerator.type == String) {
          defaultValue = "''";
        } else if (propertyGenerator.type == int ||
            propertyGenerator.type == double ||
            propertyGenerator.type == num) {
          defaultValue = 0;
        }
      }
      output.writeln("          defaultValue: $defaultValue,");
      output.write(
          "          type: ${propertyGenerator.type},logChanges: ${propertyGenerator.field.logChanges}, foreignKey: ${propertyGenerator.propertyType == PropertyType.PERSISTENT_OBJECT},externalKey: ${propertyGenerator.field.externalKey},width: ${propertyGenerator.field.width},tootltipsOnContent: ${propertyGenerator.field.tootltipsOnContent});\n");
    });
    bool createBaseFields = !classGenerator.table.sessionIdsRole;
    var fields = classGenerator.properties
        .map((PropertyGenerator e) => "          '${e.name}': ${e.name}")
        .toList()
        .join(',\n');
    output.writeln(" static TableSchema schema = new TableSchema(");
    output.writeln("tableName: '${classGenerator.type}',");
    output.writeln("tableType: ${classGenerator.type},");
    output.writeln("tableId: ${classGenerator.table.tableId},");
    output.writeln("logChanges: ${classGenerator.table.logChanges},");
    output.writeln("isView: ${classGenerator.table.isView},");
    output.writeln("sessionIdsRole: ${classGenerator.table.sessionIdsRole},");
    output.writeln(
        "idField: ${createBaseFields && classGenerator.table.idField},");
    output.writeln(
        "deletedField: ${createBaseFields && classGenerator.table.deletedField},");
    output.writeln(
        "modifiedDateField: ${createBaseFields && classGenerator.table.modifiedDateField},");
    output.writeln(
        "modifiedTimeField: ${createBaseFields && classGenerator.table.modifiedTimeField},");
    output.writeln(
        "modifiedByField: ${createBaseFields && classGenerator.table.modifiedByField},");

    output.writeln("cacheValues: ${classGenerator.table.cacheValues},");
    output.writeln("createScript: '''${classGenerator.table.createScript}''',");
    output.writeln("queryString: '''${classGenerator.table.queryString}''',");

    output.writeln("superSchema: \$${classGenerator.superClass}.schema,");
    output.writeln('fields: {$fields\n      });');
    output.writeln('}');
  }

  generateFieldDescriptors(List<PropertyGenerator> simpleProperties) {}

  processAll() {
    _classesOrdered.forEach(processClass);
    for (PropertyGenerator each in fieldsMap.values) {
      if (each.field.parentTable != null) {
        PropertyGenerator parentFieldGenerator =
        fieldsMap['${each.field.parentTable}|${each.field.parentField}'];
        if (parentFieldGenerator == null) {
          throw new Exception(
              'Parent field not found: ${each.field.parentTable} -> ${each.field.parentField}');
        }

        Field field = new Field(
            parentTable: each.field.parentTable,
            parentField: each.field.parentField,
            label: parentFieldGenerator.field.label,
            title: parentFieldGenerator.field.title,
            tootltipsOnContent: parentFieldGenerator.field.tootltipsOnContent,
            width: parentFieldGenerator.field.width);

        each.field = field;
      }
    }
  }

  processClass(Type classType) {
    var classMirror = classMirrors[classType];
    var generatorClass = new ClassGenerator();
    classGenerators.add(generatorClass);
    generatorClass.type = classMirror.reflectedType;
    if (!classMirror.metadata.isEmpty) {
      classMirror.metadata.where((m) => m.reflectee is Table).forEach((m) {
        generatorClass.table = m.reflectee as Table;
      });
    } else {
      generatorClass.table = new Table();
    }
    generatorClass.superClass = classMirror.superclass.reflectedType.toString();
    if (generatorClass.superClass == 'Object') {
      generatorClass.superClass = 'PersistentObject';
    }
    classMirror.declarations.forEach((Symbol name, DeclarationMirror vm) =>
        processProperty(generatorClass, name, vm));
  }

  processProperty(ClassGenerator classGenerator, name, DeclarationMirror vm) {
    if (vm is VariableMirror) {
      PropertyGenerator property = new PropertyGenerator();
      classGenerator.properties.add(property);
      property.name = MirrorSystem.getName(name);
      property.processVariableMirror(vm);
      fieldsMap['${classGenerator.type}|${property.name}'] = property;
    }
  }
}

class PropertyGenerator {
//  PropertyDescriptor descriptor;
  String name;
  Field field;

  Type type;
  Type listElementType;
  PropertyType propertyType = PropertyType.SIMPLE;
  String toString() => 'PropertyGenerator($name,$type,$propertyType)';
  String get commentLine => '  // $type $name\n';

  processVariableMirror(VariableMirror vm) {
    vm.metadata.where((m) => m.reflectee is Field).forEach((m) {
      field = m.reflectee as Field;
    });
    if (field == null) {
      field = const Field();
    }
    Type t = vm.type.reflectedType;
    type = t;
    if (t == int ||
        t == double ||
        t == String ||
        t == DateTime ||
        t == Map ||
        t == bool ||
        t == num) {
      return;
    }

    propertyType = PropertyType.PERSISTENT_OBJECT;
  }
}

class ClassGenerator {
  Table table;
  Type type;
  String superClass;
  List<PropertyGenerator> properties = new List<PropertyGenerator>();
  String toString() => 'ClassGenerator($properties)';
}
