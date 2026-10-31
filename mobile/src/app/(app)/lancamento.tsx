import { router, useLocalSearchParams, useNavigation } from 'expo-router';
import { useEffect, useState } from 'react';
import { Alert, Pressable, Text, View } from 'react-native';
import { useAuth } from '../../lib/auth';
import { apagarLancamento, listarLancamentos, salvarLancamento, valoresPorRota } from '../../lib/lancamentos';
import { formatarDia, formatarReais } from '../../lib/quinzena';
import { supabase } from '../../lib/supabase';
import { Botao, Campo, Cartao, Erro, Rotulo, Tela, estilos } from '../../ui/componentes';
import { cores } from '../../ui/tema';

const paraTexto = (n: number | null | undefined) => (n == null ? '' : n.toFixed(2).replace('.', ','));
const paraNumero = (t: string) => Number(t.replace(',', '.').trim());

export default function LancamentoForm() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  const navegacao = useNavigation();
  const { motorista, recarregarMotorista } = useAuth();

  const [dia, setDia] = useState(() => {
    const h = new Date();
    return new Date(h.getFullYear(), h.getMonth(), h.getDate());
  });
  const [rota, setRota] = useState<string | null>(null);
  const [anjun, setAnjun] = useState('');
  const [imile, setImile] = useState('');
  const [valorAnjun, setValorAnjun] = useState(paraTexto(motorista?.valorAnjun));
  const [valorImile, setValorImile] = useState(paraTexto(motorista?.valorImile));
  const [erro, setErro] = useState<string | null>(null);
  const [salvando, setSalvando] = useState(false);

  useEffect(() => {
    navegacao.setOptions({ title: id ? 'Corrigir lançamento' : 'Novo lançamento' });
    if (!id) return;
    listarLancamentos().then((lista) => {
      const l = lista.find((x) => x.id === id);
      if (!l) return;
      setDia(l.dia);
      setRota(l.rota);
      setAnjun(String(l.anjun));
      setImile(String(l.imile));
      setValorAnjun(paraTexto(l.valorAnjun));
      setValorImile(paraTexto(l.valorImile));
    });
  }, [id, navegacao]);

  function escolherRota(nome: string) {
    setRota(nome);
    const valor = paraTexto(valoresPorRota[nome]);
    setValorAnjun(valor);
    setValorImile(valor);
  }

  function mudarDia(dias: number) {
    setDia((d) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + dias));
  }

  const qAnjun = Number(anjun || 0);
  const qImile = Number(imile || 0);
  const vAnjun = paraNumero(valorAnjun || '0');
  const vImile = paraNumero(valorImile || '0');
  const ganho = qAnjun * vAnjun + qImile * vImile;

  async function salvar() {
    setErro(null);
    if (![qAnjun, qImile].every((n) => Number.isInteger(n) && n >= 0)) return setErro('Quantidade inválida.');
    if (qAnjun + qImile === 0) return setErro('Informe ao menos um pacote.');
    if ((qAnjun > 0 && !(vAnjun > 0)) || (qImile > 0 && !(vImile > 0))) return setErro('Informe o valor por pacote.');

    setSalvando(true);
    try {
      await salvarLancamento({ id, dia, anjun: qAnjun, imile: qImile, valorAnjun: vAnjun, valorImile: vImile, rota });
      // Lembra os valores para o próximo lançamento.
      if (motorista && (vAnjun !== motorista.valorAnjun || vImile !== motorista.valorImile)) {
        await supabase
          .from('motoristas')
          .update({ valor_anjun: vAnjun > 0 ? vAnjun : null, valor_imile: vImile > 0 ? vImile : null })
          .eq('id', motorista.id);
        await recarregarMotorista();
      }
      router.back();
    } catch {
      setErro('Não foi possível salvar. Verifique a conexão.');
    } finally {
      setSalvando(false);
    }
  }

  function confirmarApagar() {
    if (!id) return;
    Alert.alert('Apagar lançamento', 'Tem certeza?', [
      { text: 'Cancelar', style: 'cancel' },
      {
        text: 'Apagar',
        style: 'destructive',
        onPress: async () => {
          try {
            await apagarLancamento(id);
            router.back();
          } catch {
            setErro('Não foi possível apagar.');
          }
        },
      },
    ]);
  }

  return (
    <Tela>
      <Cartao>
        <Rotulo>Dia</Rotulo>
        <View style={estilos.linha}>
          <Pressable onPress={() => mudarDia(-1)} hitSlop={12}>
            <Text style={{ fontSize: 24, color: cores.primaria }}>‹</Text>
          </Pressable>
          <Text style={[estilos.texto, { fontWeight: '600' }]}>{formatarDia(dia)}</Text>
          <Pressable onPress={() => mudarDia(1)} hitSlop={12}>
            <Text style={{ fontSize: 24, color: cores.primaria }}>›</Text>
          </Pressable>
        </View>
      </Cartao>

      <Cartao>
        <Rotulo>Rota</Rotulo>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
          {Object.entries(valoresPorRota).map(([nome, valor]) => {
            const ativo = rota === nome;
            return (
              <Pressable
                key={nome}
                onPress={() => escolherRota(nome)}
                style={{
                  paddingHorizontal: 14,
                  paddingVertical: 8,
                  borderRadius: 20,
                  borderWidth: 1,
                  borderColor: cores.primaria,
                  backgroundColor: ativo ? cores.primaria : 'transparent',
                }}
              >
                <Text style={{ color: ativo ? '#fff' : cores.primaria, fontWeight: '600' }}>
                  {nome} · {formatarReais(valor)}
                </Text>
              </Pressable>
            );
          })}
        </View>
      </Cartao>

      <View style={{ flexDirection: 'row', gap: 12 }}>
        <View style={{ flex: 1 }}>
          <Campo rotulo="Pacotes Anjun" value={anjun} onChangeText={setAnjun} keyboardType="number-pad" />
        </View>
        <View style={{ flex: 1 }}>
          <Campo rotulo="Valor Anjun (R$)" value={valorAnjun} onChangeText={setValorAnjun} keyboardType="decimal-pad" />
        </View>
      </View>
      <View style={{ flexDirection: 'row', gap: 12 }}>
        <View style={{ flex: 1 }}>
          <Campo rotulo="Pacotes iMile" value={imile} onChangeText={setImile} keyboardType="number-pad" />
        </View>
        <View style={{ flex: 1 }}>
          <Campo rotulo="Valor iMile (R$)" value={valorImile} onChangeText={setValorImile} keyboardType="decimal-pad" />
        </View>
      </View>

      <Cartao>
        <Rotulo>Ganho deste lançamento</Rotulo>
        <Text style={estilos.numeroGrande}>{formatarReais(Number.isFinite(ganho) ? ganho : 0)}</Text>
      </Cartao>

      <Erro mensagem={erro} />
      <Botao titulo="Salvar" onPress={salvar} carregando={salvando} />
      {id ? <Botao titulo="Apagar" variante="perigo" onPress={confirmarApagar} /> : null}
    </Tela>
  );
}
