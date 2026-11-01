import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect, useRef } from 'react';
import { Alert, Linking, Text, View } from 'react-native';
import { AuthProvider, useAuth } from '../lib/auth';
import { temAtualizacao, useConfigApp, versaoAtual } from '../lib/configApp';
import { supabaseConfigurado } from '../lib/supabase';
import { Botao, Carregando, estilos } from '../ui/componentes';
import { cores } from '../ui/tema';

function Rotas() {
  const { carregando, sessao, motorista, sair } = useAuth();
  const { config, carregando: carregandoConfig } = useConfigApp();
  const avisou = useRef(false);

  // Avisa uma vez por abertura quando o Actions publicou um APK mais novo.
  useEffect(() => {
    if (avisou.current || !config || !temAtualizacao(config)) return;
    avisou.current = true;
    Alert.alert(
      `Nova versão ${config.ultimaVersao}`,
      `${config.notasAtualizacao ?? 'Nova versão disponível.'}\n\nVocê está na ${versaoAtual}.`,
      [
        { text: 'Depois', style: 'cancel' },
        { text: 'Atualizar', onPress: () => Linking.openURL(config.apkUrl!) },
      ],
    );
  }, [config]);

  if (carregando || carregandoConfig) return <Carregando />;

  // Modo manutenção vale para todos, menos admin.
  if (config?.manutencao && !motorista?.admin) {
    return (
      <View style={[estilos.tela, estilos.conteudo, { justifyContent: 'center' }]}>
        <Text style={estilos.titulo}>Em manutenção</Text>
        <Text style={estilos.texto}>{config.mensagemManutencao ?? 'O app volta em breve.'}</Text>
        {sessao ? <Botao titulo="Sair" onPress={sair} variante="secundario" /> : null}
      </View>
    );
  }

  // Logado mas sem perfil ou com a conta desativada pelo admin.
  if (sessao && (!motorista || !motorista.ativo)) {
    return (
      <View style={[estilos.tela, estilos.conteudo, { justifyContent: 'center' }]}>
        <Text style={estilos.titulo}>Conta sem acesso</Text>
        <Text style={estilos.texto}>
          {motorista ? 'Sua conta está desativada. Fale com o administrador.' : 'Seu perfil de motorista não foi encontrado.'}
        </Text>
        <Botao titulo="Sair" onPress={sair} variante="secundario" />
      </View>
    );
  }

  const logado = !!sessao;
  return (
    <Stack
      screenOptions={{
        headerStyle: { backgroundColor: cores.primaria },
        headerTintColor: '#fff',
        contentStyle: { backgroundColor: cores.fundo },
      }}
    >
      <Stack.Protected guard={logado}>
        <Stack.Screen name="(app)" options={{ headerShown: false }} />
      </Stack.Protected>
      <Stack.Protected guard={!logado}>
        <Stack.Screen name="login" options={{ headerShown: false }} />
        <Stack.Screen name="cadastro" options={{ title: 'Criar conta' }} />
      </Stack.Protected>
    </Stack>
  );
}

export default function Layout() {
  if (!supabaseConfigurado) {
    return (
      <View style={[estilos.tela, estilos.conteudo, { justifyContent: 'center' }]}>
        <Text style={estilos.titulo}>Supabase não configurado</Text>
        <Text style={estilos.texto}>
          Crie o arquivo .env a partir do .env.example com EXPO_PUBLIC_SUPABASE_URL e EXPO_PUBLIC_SUPABASE_KEY.
        </Text>
      </View>
    );
  }
  return (
    <AuthProvider>
      <StatusBar style="light" />
      <Rotas />
    </AuthProvider>
  );
}
