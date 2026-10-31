import type { ReactNode } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  type TextInputProps,
} from 'react-native';
import { cores } from './tema';

export function Tela({ children }: { children: ReactNode }) {
  return (
    <ScrollView style={estilos.tela} contentContainerStyle={estilos.conteudo} keyboardShouldPersistTaps="handled">
      {children}
    </ScrollView>
  );
}

export function Cartao({ children }: { children: ReactNode }) {
  return <View style={estilos.cartao}>{children}</View>;
}

export function Titulo({ children }: { children: ReactNode }) {
  return <Text style={estilos.titulo}>{children}</Text>;
}

export function Rotulo({ children }: { children: ReactNode }) {
  return <Text style={estilos.rotulo}>{children}</Text>;
}

export function Campo(props: TextInputProps & { rotulo: string }) {
  const { rotulo, style, ...resto } = props;
  return (
    <View style={{ gap: 4 }}>
      <Rotulo>{rotulo}</Rotulo>
      <TextInput placeholderTextColor={cores.textoSuave} style={[estilos.campo, style]} {...resto} />
    </View>
  );
}

export function Botao(props: {
  titulo: string;
  onPress: () => void;
  carregando?: boolean;
  variante?: 'primario' | 'secundario' | 'perigo';
  desativado?: boolean;
}) {
  const { titulo, onPress, carregando, variante = 'primario', desativado } = props;
  const corFundo = variante === 'primario' ? cores.primaria : variante === 'perigo' ? cores.erro : cores.cartao;
  const corTexto = variante === 'secundario' ? cores.primaria : '#fff';
  return (
    <Pressable
      onPress={onPress}
      disabled={carregando || desativado}
      style={({ pressed }) => [
        estilos.botao,
        { backgroundColor: corFundo, opacity: pressed || desativado ? 0.6 : 1 },
        variante === 'secundario' && { borderWidth: 1, borderColor: cores.primaria },
      ]}
    >
      {carregando ? <ActivityIndicator color={corTexto} /> : <Text style={[estilos.textoBotao, { color: corTexto }]}>{titulo}</Text>}
    </Pressable>
  );
}

export function Erro({ mensagem }: { mensagem: string | null }) {
  if (!mensagem) return null;
  return <Text style={estilos.erro}>{mensagem}</Text>;
}

export function Carregando() {
  return (
    <View style={[estilos.tela, { justifyContent: 'center', alignItems: 'center' }]}>
      <ActivityIndicator size="large" color={cores.primaria} />
    </View>
  );
}

export const estilos = StyleSheet.create({
  tela: { flex: 1, backgroundColor: cores.fundo },
  conteudo: { padding: 16, gap: 12 },
  cartao: {
    backgroundColor: cores.cartao,
    borderRadius: 12,
    padding: 16,
    gap: 8,
    borderWidth: 1,
    borderColor: cores.borda,
  },
  titulo: { fontSize: 22, fontWeight: '700', color: cores.texto },
  rotulo: { fontSize: 14, color: cores.textoSuave },
  texto: { fontSize: 16, color: cores.texto },
  numeroGrande: { fontSize: 28, fontWeight: '700', color: cores.primariaEscura },
  campo: {
    backgroundColor: cores.cartao,
    borderWidth: 1,
    borderColor: cores.borda,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 12,
    fontSize: 16,
    color: cores.texto,
  },
  botao: { borderRadius: 10, paddingVertical: 14, alignItems: 'center', justifyContent: 'center' },
  textoBotao: { fontSize: 16, fontWeight: '600' },
  erro: { color: cores.erro, fontSize: 14 },
  linha: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8 },
});
