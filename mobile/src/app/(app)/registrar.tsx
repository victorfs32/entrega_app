import * as ImagePicker from 'expo-image-picker';
import * as Location from 'expo-location';
import { router } from 'expo-router';
import { useState } from 'react';
import { Alert, Image, Pressable, Text, View } from 'react-native';
import { useAuth } from '../../lib/auth';
import { jaEntregue, registrarEntrega } from '../../lib/entregas';
import { Botao, Campo, Erro, Rotulo, Tela } from '../../ui/componentes';
import { cores } from '../../ui/tema';

const TRANSPORTADORAS = ['Anjun', 'iMile'];

async function localizacaoAtual(): Promise<{ lat: number; lng: number } | null> {
  try {
    const { status } = await Location.requestForegroundPermissionsAsync();
    if (status !== 'granted') return null;
    const pos = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced });
    return { lat: pos.coords.latitude, lng: pos.coords.longitude };
  } catch {
    return null; // sem GPS não impede a baixa
  }
}

export default function Registrar() {
  const { sessao } = useAuth();
  const [codigo, setCodigo] = useState('');
  const [transportadora, setTransportadora] = useState<string | null>(null);
  const [recebedor, setRecebedor] = useState('');
  const [fotoUri, setFotoUri] = useState<string | null>(null);
  const [erro, setErro] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  async function tirarFoto() {
    const permissao = await ImagePicker.requestCameraPermissionsAsync();
    if (!permissao.granted) return setErro('Permita o uso da câmera para tirar a foto.');
    const resultado = await ImagePicker.launchCameraAsync({ mediaTypes: ['images'], quality: 0.5 });
    if (!resultado.canceled) setFotoUri(resultado.assets[0].uri);
  }

  async function salvar() {
    setErro(null);
    const cod = codigo.trim().toUpperCase();
    if (!cod) return setErro('Informe o código do pacote.');
    if (!fotoUri) return setErro('Tire a foto do comprovante.');
    if (!sessao) return;

    setEnviando(true);
    try {
      if (await jaEntregue(cod)) {
        setErro('Este pacote já foi entregue.');
        return;
      }
      const local = await localizacaoAtual();
      await registrarEntrega({
        uid: sessao.user.id,
        codigo: cod,
        transportadora,
        recebedor: recebedor.trim() || null,
        fotoUri,
        lat: local?.lat ?? null,
        lng: local?.lng ?? null,
      });
      Alert.alert('Entrega registrada', cod);
      router.back();
    } catch {
      setErro('Não foi possível enviar. Verifique a conexão e tente de novo.');
    } finally {
      setEnviando(false);
    }
  }

  return (
    <Tela>
      <Campo rotulo="Código do pacote" value={codigo} onChangeText={setCodigo} autoCapitalize="characters" autoCorrect={false} />

      <Rotulo>Transportadora</Rotulo>
      <View style={{ flexDirection: 'row', gap: 8 }}>
        {TRANSPORTADORAS.map((t) => {
          const ativo = transportadora === t;
          return (
            <Pressable
              key={t}
              onPress={() => setTransportadora(ativo ? null : t)}
              style={{
                paddingHorizontal: 16,
                paddingVertical: 8,
                borderRadius: 20,
                borderWidth: 1,
                borderColor: cores.primaria,
                backgroundColor: ativo ? cores.primaria : 'transparent',
              }}
            >
              <Text style={{ color: ativo ? '#fff' : cores.primaria, fontWeight: '600' }}>{t}</Text>
            </Pressable>
          );
        })}
      </View>

      <Campo rotulo="Quem recebeu (opcional)" value={recebedor} onChangeText={setRecebedor} />

      {fotoUri ? (
        <Image source={{ uri: fotoUri }} style={{ width: '100%', aspectRatio: 3 / 4, borderRadius: 10 }} />
      ) : null}
      <Botao titulo={fotoUri ? 'Tirar outra foto' : 'Tirar foto'} variante="secundario" onPress={tirarFoto} />

      <Erro mensagem={erro} />
      <Botao titulo="Registrar entrega" onPress={salvar} carregando={enviando} />
    </Tela>
  );
}
