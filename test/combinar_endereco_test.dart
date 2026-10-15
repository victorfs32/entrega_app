import 'package:entrega_app/services/rota_lida_service.dart';
import 'package:entrega_app/utils/combinar_endereco.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const paradas = [
    Parada(
      id: '1',
      endereco: 'Rua Alameda Verde, 280',
      local: 'Condomínio Eco Way Eusebio, Coaçu, Eusébio',
      pacotes: 7,
    ),
    Parada(
      id: '2',
      endereco: 'Rua Alameda Verde, 100',
      local: 'Coaçu, Eusébio, 61760-000',
      pacotes: 6,
    ),
    Parada(
      id: '3',
      endereco: 'Condomínio Horizontal Jardins Ibiza',
      local: '700 CE-040, Coaçu, 61760-908',
      pacotes: 4,
    ),
    Parada(
      id: '4',
      endereco: 'Avenida José Moraes de Almeida, 163',
      local: 'Coaçu, Eusébio, 61760-000',
      pacotes: 1,
    ),
  ];

  test('acha a parada pelo nome da rua e número da etiqueta', () {
    const etiqueta = '''
AJ123456789012345
Destinatário: Maria Souza
RUA ALAMEDA VERDE, 100
Coaçu - Eusébio - CE
CEP 61760-000
Tel (85) 99999-0000
''';

    final achadas = CombinarEndereco.procurar(etiqueta, paradas);

    expect(achadas.first.parada.id, '2');
    expect(achadas.first.exata, isTrue);
    // A 280 tem a mesma rua, mas o número não bate: não entra.
    expect(achadas.map((c) => c.parada.id), isNot(contains('1')));
  });

  test('tolera uma letra errada do OCR', () {
    const etiqueta = 'Av Jose Moraes de Almeida 163\nCoacu Eusebio';

    final achadas = CombinarEndereco.procurar(
      etiqueta.replaceFirst('Moraes', 'Moraos'),
      paradas,
    );

    expect(achadas.first.parada.id, '4');
  });

  test('parada sem número (condomínio) é achada só pelo nome', () {
    const etiqueta = 'Cond Horizontal Jardins Ibiza\nBloco B apto 22';

    final achadas = CombinarEndereco.procurar(etiqueta, paradas);

    expect(achadas.first.parada.id, '3');
  });

  test('etiqueta real do celular (OCR com ruído e palavra quebrada)', () {
    // Texto lido de uma etiqueta de verdade: o "Rua" veio partido em duas
    // linhas e há muito texto em volta.
    const etiqueta = '''
Retetente
TO
2809 28 27
Dolbvey
Eris Rua Shes Carein8: Sao paulo Sae Paulc, 0300
Cleozinha 2..
casa cinza porta grarde, Coaçu Ru
a dos Girassóis 125, Eusébio, Cear
a, 6 771320
dTikTok Shop 61771320
3320122157217
0.460 KG
''';

    const rota = [
      ...paradas,
      Parada(
        id: '16',
        endereco: 'Rua dos Girassóis, 125',
        local: 'Prq Res Estr Do Fio, Eusébio, 61760-000',
      ),
    ];

    final achadas = CombinarEndereco.procurar(etiqueta, rota);

    expect(achadas, isNotEmpty);
    expect(achadas.first.parada.id, '16');
    expect(achadas.first.exata, isTrue);
  });

  test('nome da rua partido em duas linhas ainda é achado', () {
    const etiqueta = 'Rua das Pal\nmeiras, 55\nCoaçu';

    const rota = [Parada(id: '9', endereco: 'Rua das Palmeiras, 55')];

    expect(CombinarEndereco.procurar(etiqueta, rota).first.parada.id, '9');
  });

  test('etiqueta de endereço que não está na rota não casa com nada', () {
    const etiqueta = 'Rua das Palmeiras, 55\nFortaleza - CE';

    expect(CombinarEndereco.procurar(etiqueta, paradas), isEmpty);
  });
}
