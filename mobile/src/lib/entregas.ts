import { BUCKET_FOTOS, supabase } from './supabase';

export type Entrega = {
  id: string;
  codigo: string;
  transportadora: string | null;
  recebedor: string | null;
  fotoPath: string | null;
  lat: number | null;
  lng: number | null;
  dataEntrega: Date;
};

type Linha = {
  id: string;
  codigo: string;
  transportadora: string | null;
  recebedor: string | null;
  foto_path: string | null;
  lat: number | null;
  lng: number | null;
  data_entrega: string;
};

export async function listarEntregas(limite = 100): Promise<Entrega[]> {
  const { data, error } = await supabase
    .from('entregas')
    .select('id, codigo, transportadora, recebedor, foto_path, lat, lng, data_entrega')
    .order('data_entrega', { ascending: false })
    .limit(limite);
  if (error) throw error;
  return (data as Linha[]).map((l) => ({
    id: l.id,
    codigo: l.codigo,
    transportadora: l.transportadora,
    recebedor: l.recebedor,
    fotoPath: l.foto_path,
    lat: l.lat,
    lng: l.lng,
    dataEntrega: new Date(l.data_entrega),
  }));
}

/** Impede bipar de novo um pacote já entregue. Falha aberta se der erro de rede. */
export async function jaEntregue(codigo: string): Promise<boolean> {
  const { data, error } = await supabase
    .from('entregas')
    .select('id')
    .eq('codigo', codigo)
    .eq('entregue', true)
    .limit(1);
  if (error) return false;
  return (data ?? []).length > 0;
}

/** Envia a foto para o Storage em <uid>/<codigo>-<hora>.jpg e devolve o caminho. */
async function enviarFoto(uid: string, codigo: string, uri: string): Promise<string> {
  const resposta = await fetch(uri);
  const bytes = await resposta.arrayBuffer();
  const nomeSeguro = codigo.replace(/[^a-zA-Z0-9_-]/g, '_');
  const caminho = `${uid}/${nomeSeguro}-${Date.now()}.jpg`;
  const { error } = await supabase.storage
    .from(BUCKET_FOTOS)
    .upload(caminho, bytes, { contentType: 'image/jpeg' });
  if (error) throw error;
  return caminho;
}

export async function registrarEntrega(dados: {
  uid: string;
  codigo: string;
  transportadora: string | null;
  recebedor: string | null;
  fotoUri: string;
  lat: number | null;
  lng: number | null;
}) {
  const fotoPath = await enviarFoto(dados.uid, dados.codigo, dados.fotoUri);
  const { error } = await supabase.from('entregas').insert({
    codigo: dados.codigo,
    transportadora: dados.transportadora,
    recebedor: dados.recebedor,
    foto_path: fotoPath,
    lat: dados.lat,
    lng: dados.lng,
  });
  if (error) throw error;
}

/** Link temporário (1 hora) para ver a foto do bucket privado. */
export async function urlDaFoto(caminho: string): Promise<string | null> {
  const { data } = await supabase.storage.from(BUCKET_FOTOS).createSignedUrl(caminho, 3600);
  return data?.signedUrl ?? null;
}
