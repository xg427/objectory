/// Warning! That file is generated. Do not edit it manually
part of domain_model;

class $User {
  static Field<int> get id =>
      const Field<int>(id: 'id',label: '',title: '',
          type: int,logChanges: true, foreignKey: false);
  static Field<String> get name =>
      const Field<String>(id: 'name',label: '',title: '',
          type: String,logChanges: true, foreignKey: false);
  static Field<String> get email =>
      const Field<String>(id: 'email',label: '',title: '',
          type: String,logChanges: true, foreignKey: false);
  static Field<String> get login =>
      const Field<String>(id: 'login',label: '',title: '',
          type: String,logChanges: true, foreignKey: false);
 static TableSchema schema = new TableSchema(
      tableName: 'User',
      logChanges: false,
      fields: {
          'name': name,
          'email': email,
          'login': login
      });
}

class User extends PersistentObject {
  TableSchema get $schema => $User.schema;
  String get name => getProperty('name');
  set name (String value) => setProperty('name',value);
  String get email => getProperty('email');
  set email (String value) => setProperty('email',value);
  String get login => getProperty('login');
  set login (String value) => setProperty('login',value);
}

class $Person {
  static Field<int> get id =>
      const Field<int>(id: 'id',label: '',title: '',
          type: int,logChanges: true, foreignKey: false);
  static Field<String> get firstName =>
      const Field<String>(id: 'firstName',label: '',title: '',
          type: String,logChanges: true, foreignKey: false);
  static Field<String> get lastName =>
      const Field<String>(id: 'lastName',label: '',title: '',
          type: String,logChanges: true, foreignKey: false);
  static Field<int> get father =>
      const Field<int>(id: 'father',label: '',title: '',
          type: Person,logChanges: true, foreignKey: true);
  static Field<int> get mother =>
      const Field<int>(id: 'mother',label: '',title: '',
          type: Person,logChanges: true, foreignKey: true);
 static TableSchema schema = new TableSchema(
      tableName: 'Person',
      logChanges: true,
      fields: {
          'firstName': firstName,
          'lastName': lastName,
          'father': father,
          'mother': mother
      });
}

class Person extends PersistentObject {
  TableSchema get $schema => $Person.schema;
  String get firstName => getProperty('firstName');
  set firstName (String value) => setProperty('firstName',value);
  String get lastName => getProperty('lastName');
  set lastName (String value) => setProperty('lastName',value);
  Person get father => getLinkedObject('father', Person);
  set father (Person value) => setLinkedObject('father',value);
  Person get mother => getLinkedObject('mother', Person);
  set mother (Person value) => setLinkedObject('mother',value);
}

class $Author {
  static Field<int> get id =>
      const Field<int>(id: 'id',label: '',title: '',
          type: int,logChanges: true, foreignKey: false);
  static Field<String> get name =>
      const Field<String>(id: 'name',label: '',title: '',
          type: String,logChanges: true, foreignKey: false);
  static Field<String> get email =>
      const Field<String>(id: 'email',label: '',title: '',
          type: String,logChanges: true, foreignKey: false);
  static Field<int> get age =>
      const Field<int>(id: 'age',label: '',title: '',
          type: int,logChanges: true, foreignKey: false);
 static TableSchema schema = new TableSchema(
      tableName: 'Author',
      logChanges: true,
      fields: {
          'name': name,
          'email': email,
          'age': age
      });
}

class Author extends PersistentObject {
  TableSchema get $schema => $Author.schema;
  String get name => getProperty('name');
  set name (String value) => setProperty('name',value);
  String get email => getProperty('email');
  set email (String value) => setProperty('email',value);
  int get age => getProperty('age');
  set age (int value) => setProperty('age',value);
}

registerClasses(Objectory objectoryParam) {
  objectoryParam.registerClass(User,()=>new User(),()=>new List<User>(), {});
  objectoryParam.registerClass(Person,()=>new Person(),()=>new List<Person>(), {'father': Person, 'mother': Person});
  objectoryParam.registerClass(Author,()=>new Author(),()=>new List<Author>(), {});
}
