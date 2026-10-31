import { router } from 'expo-router';
import { useState } from 'react';
import { Alert } from 'react-native';
import { supabase } from '../lib/supabase';
import { Botao, Campo, Erro, Tela } from '../ui/componentes';

export default function Cadastro() {
  const [nome, setNome] = useState('');
  const [telefone, setTelefone] = useState('');
  const [email, setEmail] = useState('');
  const [senha, setSenha] = useState('');
  const [erro, setErro] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  async function cadastrar() {
    setErro(null);
    if (nome.trim().length < 2) return setErro('Informe seu nome.');
    if (senha.length < 6) return setErro('A senha precisa ter pelo menos 6 caracteres.');

    setEnviando(true);
    // O perfil do motorista é criado no banco (gatilho) com nome e telefone.
    const { data, error } = await supabase.auth.signUp({
      email: email.trim(),
      password: senha,
      options: { data: { nome: nome.trim(), telefone: telefone.trim() } },
    });
    setEnviando(false);

    if (error) return setErro(error.message.includes('already') ? 'Este e-mail já está cadastrado.' : error.message);
    if (!data.session) {
      Alert.alert('Conta criada', 'Enviamos um e-mail de confirmação. Confirme e depois faça login.');
      router.back();
    }
  }

  return (
    <Tela>
      <Campo rotulo="Nome" value={nome} onChangeText={setNome} autoComplete="name" />
      <Campo rotulo="Telefone" value={telefone} onChangeText={setTelefone} keyboardType="phone-pad" />
      <Campo rotulo="E-mail" value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" />
      <Campo rotulo="Senha" value={senha} onChangeText={setSenha} secureTextEntry />
      <Erro mensagem={erro} />
      <Botao titulo="Criar conta" onPress={cadastrar} carregando={enviando} desativado={!email || !senha} />
    </Tela>
  );
}
