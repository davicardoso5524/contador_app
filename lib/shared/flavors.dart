/// Centraliza definição de todos os sabores da aplicação
/// Fonte única de verdade para os nomes e IDs dos sabores.
///
/// Inclui:
/// - Sabores originais: Frango, Frango c/ Bacon, Carne do Sol, Queijo, Calabresa, Pizza
/// - Sabores adicionais: Churritos, Doce de Leite, Chocolate, Kibes
///
/// Uso no relatório: allFlavorIds percorre todos os 10 sabores (0 se não vendido naquele dia)
library;

class Flavors {
  // Sabores originais
  static const String idFrango = 'frango';
  static const String nameFrango = 'Frango';

  static const String idFrangoBacon = 'frango_bacon';
  static const String nameFrangoBacon = 'Frango c/ Bacon';

  static const String idCarnedoSol = 'carne_do_sol';
  static const String nameCarnedoSol = 'Carne do Sol';

  static const String idQueijo = 'queijo';
  static const String nameQueijo = 'Queijo';

  static const String idCalabresa = 'calabresa';
  static const String nameCalabresa = 'Calabresa';

  static const String idPizza = 'pizza';
  static const String namePizza = 'Pizza';

  // Sabores adicionais (More Flavors)
  static const String idChurritos = 'churritos';
  static const String nameChurritos = 'Churritos';

  static const String idDocedeLeite = 'doce-de-leite';
  static const String nameDocedeLeite = 'Doce de Leite';

  static const String idChocolate = 'chocolate';
  static const String nameChocolate = 'Chocolate';

  static const String idKibes = 'kibes';
  static const String nameKibes = 'Kibes';

  /// Lista de todos os sabores (originais + adicionais) com ID e nome
  static const List<Map<String, String>> allFlavors = [
    {'id': idFrango, 'name': nameFrango},
    {'id': idFrangoBacon, 'name': nameFrangoBacon},
    {'id': idCarnedoSol, 'name': nameCarnedoSol},
    {'id': idQueijo, 'name': nameQueijo},
    {'id': idCalabresa, 'name': nameCalabresa},
    {'id': idPizza, 'name': namePizza},
    {'id': idChurritos, 'name': nameChurritos},
    {'id': idDocedeLeite, 'name': nameDocedeLeite},
    {'id': idChocolate, 'name': nameChocolate},
    {'id': idKibes, 'name': nameKibes},
  ];

  /// Mapa de ID -> Nome para busca rápida
  static final Map<String, String> flavorNames = {
    for (var f in allFlavors) f['id']!: f['name']!,
  };

  /// Lista apenas de IDs
  static const List<String> allFlavorIds = [
    idFrango,
    idFrangoBacon,
    idCarnedoSol,
    idQueijo,
    idCalabresa,
    idPizza,
    idChurritos,
    idDocedeLeite,
    idChocolate,
    idKibes,
  ];

  /// Retorna o nome do sabor pela ID
  static String getFlavorName(String id) {
    return flavorNames[id] ?? 'Desconhecido';
  }
}
