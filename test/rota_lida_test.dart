import 'package:entrega_app/services/rota_lida_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Linhas na ordem de leitura da tela de uma parada do Circuit.
  const telaDaParada = [
    'Rua Sarah Rosa',
    'Av. Washington Soares',
    '2',
    '1',
    'Destino',
    'Rua Alameda Verde, 100',
    'Entregue',
    '2/45',
    'Entregue ao destinatário',
    '14:52',
    'Desfazer',
    'Adicionar notas',
    'Coaçu, Eusébio, 61760-000',
    'ID',
    '2 Originally 2nd',
    'Primeira',
  ];

  test('lê o ID e o endereço da tela de uma parada', () {
    final parada = RotaLidaService.lerParada(telaDaParada);

    expect(parada, isNotNull);
    expect(parada!.id, '2');
    expect(parada.endereco, 'Rua Alameda Verde, 100');
    expect(parada.local, 'Coaçu, Eusébio, 61760-000');
  });

  test('ID e número juntos na mesma linha', () {
    final parada = RotaLidaService.lerParada([
      'Rua das Flores, 12',
      '5/45',
      'ID 17',
    ]);

    expect(parada?.id, '17');
    expect(parada?.endereco, 'Rua das Flores, 12');
  });

  ItemTela item(String texto, int x, int y) =>
      ItemTela(texto, y, x, y + 28, x + 100);

  // Lista da rota do Circuit (print do motorista): número e horário à
  // esquerda, endereço e bairro, chips (Primeira / quantidade) e o ID à direita.
  List<ItemTela> listaDaRota({required bool idJunto}) => [
    item('Rota Eusébio', 30, 270),
    item('Ponto de partida', 120, 494),
    item('14:21', 40, 525),
    item('01', 40, 588),
    item('14:52', 38, 617),
    item('Rua Alameda Verde, 280', 120, 588),
    item('Condomínio Eco Way Eusebio, Coaçu, Eusébio', 120, 617),
    item('Primeira', 140, 650),
    item('7', 285, 650),
    if (idJunto) item('ID 1', 537, 592) else ...[item('ID', 537, 592), item('1', 560, 592)],
    item('02', 40, 743),
    item('14:52', 38, 771),
    item('Rua Alameda Verde, 100', 120, 742),
    item('Coaçu, Eusébio, 61760-000', 120, 770),
    item('Primeira', 140, 803),
    item('6', 285, 803),
    if (idJunto) item('ID 2', 537, 746) else ...[item('ID', 537, 746), item('2', 560, 746)],
    item('03', 40, 897),
    item('15:09', 38, 925),
    item('Condomínio Horizontal Jardins Ibiza', 120, 895),
    item('700 CE-040, Coaçu, 61760-908', 120, 922),
    item('Primeira', 140, 956),
    item('4', 285, 956),
    if (idJunto) item('ID 3', 537, 900) else ...[item('ID', 537, 900), item('3', 560, 900)],
  ];

  for (final junto in [true, false]) {
    test('lê as paradas da lista da rota (ID ${junto ? 'junto' : 'separado'})', () {
      final paradas = RotaLidaService.lerLista(listaDaRota(idJunto: junto));

      expect(paradas.map((p) => p.id), ['1', '2', '3']);
      expect(paradas[0].endereco, 'Rua Alameda Verde, 280');
      expect(paradas[0].local, 'Condomínio Eco Way Eusebio, Coaçu, Eusébio');
      expect(paradas[0].pacotes, 7);
      expect(paradas[1].endereco, 'Rua Alameda Verde, 100');
      expect(paradas[1].pacotes, 6);
      expect(paradas[2].endereco, 'Condomínio Horizontal Jardins Ibiza');
      expect(paradas[2].local, '700 CE-040, Coaçu, 61760-908');
      expect(paradas[2].pacotes, 4);
    });
  }

  test('pinos numerados do mapa não viram linhas da lista', () {
    final mapa = [item('2', 300, 355), item('1', 350, 360), item('4', 370, 463)];

    expect(RotaLidaService.lerLista(mapa), isEmpty);
  });

  test('tela sem ID (mapa, lista) não vira parada', () {
    expect(
      RotaLidaService.lerParada(['Rua Sarah Rosa', 'Destino', '12']),
      isNull,
    );
  });
}
