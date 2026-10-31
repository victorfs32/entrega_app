import { Stack } from 'expo-router';
import { cores } from '../../ui/tema';

export default function AppLayout() {
  return (
    <Stack
      screenOptions={{
        headerStyle: { backgroundColor: cores.primaria },
        headerTintColor: '#fff',
        contentStyle: { backgroundColor: cores.fundo },
      }}
    >
      <Stack.Screen name="index" options={{ title: 'Início' }} />
      <Stack.Screen name="lancamentos" options={{ title: 'Lançamentos' }} />
      <Stack.Screen name="lancamento" options={{ title: 'Lançamento' }} />
      <Stack.Screen name="entregas" options={{ title: 'Entregas' }} />
      <Stack.Screen name="registrar" options={{ title: 'Registrar entrega' }} />
    </Stack>
  );
}
