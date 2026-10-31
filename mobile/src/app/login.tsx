import { Link } from 'expo-router';
import { useState } from 'react';
import { Text, View } from 'react-native';
import { supabase } from '../lib/supabase';
import { Botao, Campo, Erro, Tela, estilos } from '../ui/componentes';
import { cores } from '../ui/tema';

export default function Login() {
  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [erro, setErro] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  async function entrar() {
    setErro(null);
    setEnviando(true);
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password: senha });
    setEnviando(false);
    if (error) {
      setErro(error.message.includes('Email not confirmed') ? 'Confirme seu e-mail antes de entrar.' : 'E-mail ou senha incorretos.');
    }
  }

  return (
    <Tela>
      <View style={{ height: 80 }} />
      <Text style={[estilos.titulo, { fontSize: 28, color: cores.primariaEscura }]}>Entregas</Text>
      <Text style={estilos.rotulo}>Acesse sua conta de motorista</Text>
      <Campo rotulo="E-mail" value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" autoComplete="email" />
      <Campo rotulo="Senha" value={senha} onChangeText={setSenha} secureTextEntry autoComplete="password" />
      <Erro mensagem={erro} />
      <Botao titulo="Entrar" onPress={entrar} carregando={enviando} desativado={!email || !senha} />
      <Link href="/cadastro" style={{ color: cores.primaria, textAlign: 'center', padding: 12, fontSize: 16 }}>
        Não tem conta? Cadastre-se
      </Link>
    </Tela>
  );
}
