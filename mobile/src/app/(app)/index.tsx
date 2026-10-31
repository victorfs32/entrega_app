import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { RefreshControl, ScrollView, Text, View } from 'react-native';
import { useAuth } from '../../lib/auth';
import { listarLancamentos, somar, type Lancamento } from '../../lib/lancamentos';
import { fimDaQuinzena, formatarDia, formatarReais, inicioDaQuinzena, previsaoPagamento } from '../../lib/quinzena';
import { Botao, Cartao, Erro, Rotulo, estilos } from '../../ui/componentes';
import { cores } from '../../ui/tema';

export default function Inicio() {
  const { motorista, sair } = useAuth();
  const [lancamentos, setLancamentos] = useState<Lancamento[]>([]);
  const [atualizando, setAtualizando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const carregar = useCallback(async () => {
    setAtualizando(true);
    try {
      setLancamentos(await listarLancamentos());
      setErro(null);
    } catch (e) {
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

  const hoje = new Date();
  const inicio = inicioDaQuinzena(hoje);
  const fim = fimDaQuinzena(hoje);
  const quinzena = somar(lancamentos, inicio, fim);
  const doDia = somar(lancamentos, new Date(hoje.getFullYear(), hoje.getMonth(), hoje.getDate()), fim);
  const meta = motorista?.metaQuinzena ?? null;

  return (
    <ScrollView
      style={estilos.tela}
      contentContainerStyle={estilos.conteudo}
      refreshControl={<RefreshControl refreshing={atualizando} onRefresh={carregar} />}
    >
      <Text style={estilos.titulo}>Olá, {motorista?.nome.split(' ')[0] || 'motorista'}!</Text>

      <Cartao>
        <Rotulo>
          Quinzena {formatarDia(inicio)} a {formatarDia(fim)}
        </Rotulo>
        <Text style={estilos.numeroGrande}>{formatarReais(quinzena.ganho)}</Text>
        <Text style={estilos.texto}>
          {quinzena.total} pacotes (Anjun {quinzena.anjun} · iMile {quinzena.imile})
        </Text>
        {meta ? (
          <View style={{ gap: 4 }}>
            <View style={{ height: 8, borderRadius: 4, backgroundColor: cores.borda, overflow: 'hidden' }}>
              <View
                style={{
                  height: 8,
                  width: `${Math.min(100, (quinzena.ganho / meta) * 100)}%`,
                  backgroundColor: cores.sucesso,
                }}
              />
            </View>
            <Rotulo>Meta: {formatarReais(meta)}</Rotulo>
          </View>
        ) : null}
        <Rotulo>Previsão de pagamento: {formatarDia(previsaoPagamento(fim))}</Rotulo>
      </Cartao>

      <Cartao>
        <Rotulo>Hoje</Rotulo>
        <Text style={estilos.texto}>
          {doDia.total} pacotes · {formatarReais(doDia.ganho)}
        </Text>
      </Cartao>

      <Erro mensagem={erro} />

      <Botao titulo="Novo lançamento" onPress={() => router.push('/lancamento')} />
      <Botao titulo="Ver lançamentos" variante="secundario" onPress={() => router.push('/lancamentos')} />
      <Botao titulo="Registrar entrega (foto)" onPress={() => router.push('/registrar')} />
      <Botao titulo="Entregas registradas" variante="secundario" onPress={() => router.push('/entregas')} />
      <View style={{ height: 16 }} />
      <Botao titulo="Sair" variante="perigo" onPress={sair} />
    </ScrollView>
  );
}
