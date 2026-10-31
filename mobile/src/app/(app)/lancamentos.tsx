import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { FlatList, Pressable, RefreshControl, Text, View } from 'react-native';
import { ganhoDe, listarLancamentos, type Lancamento } from '../../lib/lancamentos';
import { formatarDia, formatarReais } from '../../lib/quinzena';
import { Erro, Rotulo, estilos } from '../../ui/componentes';

export default function Lancamentos() {
  const [lista, setLista] = useState<Lancamento[]>([]);
  const [atualizando, setAtualizando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    setAtualizando(true);
    try {
      setLista(await listarLancamentos());
      setErro(null);
    } catch {
      setErro('Não foi possível carregar os lançamentos.');
    } finally {
      setAtualizando(false);
    }
  }, []);

  useFocusEffect(
    useCallback(() => {
      carregar();
    }, [carregar]),
  );

  return (
    <FlatList
      style={estilos.tela}
      contentContainerStyle={estilos.conteudo}
      data={lista}
      keyExtractor={(l) => l.id}
      refreshControl={<RefreshControl refreshing={atualizando} onRefresh={carregar} />}
      ListHeaderComponent={<Erro mensagem={erro} />}
      ListEmptyComponent={atualizando ? undefined : <Rotulo>Nenhum lançamento ainda.</Rotulo>}
      renderItem={({ item }) => (
        <Pressable onPress={() => router.push({ pathname: '/lancamento', params: { id: item.id } })}>
          <View style={[estilos.cartao, { gap: 4 }]}>
            <View style={estilos.linha}>
              <Text style={[estilos.texto, { fontWeight: '600' }]}>
                {formatarDia(item.dia)}
                {item.rota ? ` · ${item.rota}` : ''}
              </Text>
              <Text style={[estilos.texto, { fontWeight: '700' }]}>{formatarReais(ganhoDe(item))}</Text>
            </View>
            <Rotulo>
              Anjun {item.anjun} × {formatarReais(item.valorAnjun)} · iMile {item.imile} × {formatarReais(item.valorImile)}
            </Rotulo>
          </View>
        </Pressable>
      )}
    />
  );
}
