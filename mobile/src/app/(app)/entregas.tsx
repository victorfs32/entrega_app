import { useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { FlatList, Image, Linking, Pressable, RefreshControl, Text, View } from 'react-native';
import { listarEntregas, urlDaFoto, type Entrega } from '../../lib/entregas';
import { Erro, Rotulo, estilos } from '../../ui/componentes';
import { cores } from '../../ui/tema';

function ItemEntrega({ entrega }: { entrega: Entrega }) {
  const [foto, setFoto] = useState<string | null>(null);
  const [aberto, setAberto] = useState(false);

  async function alternar() {
    if (!aberto && !foto && entrega.fotoPath) setFoto(await urlDaFoto(entrega.fotoPath));
    setAberto(!aberto);
  }

  return (
    <Pressable onPress={alternar}>
      <View style={[estilos.cartao, { gap: 4 }]}>
        <View style={estilos.linha}>
          <Text style={[estilos.texto, { fontWeight: '600', flexShrink: 1 }]}>{entrega.codigo}</Text>
          <Rotulo>{entrega.dataEntrega.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}</Rotulo>
        </View>
        <Rotulo>
          {[entrega.transportadora, entrega.recebedor && `Recebido por ${entrega.recebedor}`].filter(Boolean).join(' · ') ||
            'Sem detalhes'}
        </Rotulo>
        {aberto && foto ? (
          <Image source={{ uri: foto }} style={{ width: '100%', aspectRatio: 3 / 4, borderRadius: 8 }} resizeMode="cover" />
        ) : null}
        {aberto && entrega.lat != null && entrega.lng != null ? (
          <Text
            style={{ color: cores.primaria }}
            onPress={() => Linking.openURL(`https://maps.google.com/?q=${entrega.lat},${entrega.lng}`)}
          >
            Ver local no mapa
          </Text>
        ) : null}
      </View>
    </Pressable>
  );
}

export default function Entregas() {
  const [lista, setLista] = useState<Entrega[]>([]);
  const [atualizando, setAtualizando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    setAtualizando(true);
    try {
      setLista(await listarEntregas());
      setErro(null);
    } catch {
      setErro('Não foi possível carregar as entregas.');
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
      keyExtractor={(e) => e.id}
      refreshControl={<RefreshControl refreshing={atualizando} onRefresh={carregar} />}
      ListHeaderComponent={<Erro mensagem={erro} />}
      ListEmptyComponent={atualizando ? undefined : <Rotulo>Nenhuma entrega registrada.</Rotulo>}
      renderItem={({ item }) => <ItemEntrega entrega={item} />}
    />
  );
}
