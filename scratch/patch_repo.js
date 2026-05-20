const fs = require('fs');

let content = fs.readFileSync('./lib/data/repositories/bingo_repository_impl.dart', 'utf8');

// Add import
content = content.replace(
    /import 'package:cloud_functions\/cloud_functions\.dart';/,
    `import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';`
);

// Add database property
content = content.replace(
    /final FirebaseFunctions _functions;/,
    `final FirebaseFunctions _functions;
  final FirebaseDatabase _database;`
);

// Add database to constructor
content = content.replace(
    /FirebaseFunctions\? functions,\s*}\) : _firestore = firestore \?\? FirebaseFirestore\.instance,\s*_functions = functions \?\? FirebaseFunctions\.instance;/,
    `FirebaseFunctions? functions,
    FirebaseDatabase? database,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _database = database ?? FirebaseDatabase.instance;`
);

// Rewrite streamDrawnNumbers
content = content.replace(
    /@override\s*Stream<List<int>> streamDrawnNumbers\(String gameId\) {[\s\S]*?return _firestore[\s\S]*?\.doc\('live'\)[\s\S]*?\.snapshots\(\)[\s\S]*?\.map\([\s\S]*?\(doc\) => \(doc\.data\(\)\?\['drawnNumbers'\] as List\?\)\?\.cast<int>\(\) \?\? \[\],[\s\S]*?\);[\s\S]*?}/,
`  @override
  Stream<List<int>> streamDrawnNumbers(String gameId) {
    return _database
        .ref('games/live/drawnNumbers')
        .onValue
        .map((event) {
          final val = event.snapshot.value;
          if (val == null) return <int>[];
          if (val is List) {
             return val.where((e) => e != null).map((e) => int.parse(e.toString())).toList();
          }
          return <int>[];
        });
  }`
);

fs.writeFileSync('./lib/data/repositories/bingo_repository_impl.dart', content);
console.log('Repo patched!');
