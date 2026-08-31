import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'atualizacao_service.dart';

class AtualizacaoDialog {
  static Future<void> mostrar(
    BuildContext context,
    AtualizacaoInfo info,
  ) async {
    final service = AtualizacaoService();

    bool baixando = false;
    double progresso = 0;
    String? erro;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.system_update,
                    color: Colors.green,
                  ),
                  SizedBox(width: 8),
                  Text("Nova atualização"),
                ],
              ),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Versão ${info.novaVersao} disponível.",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(info.notas),
                    const SizedBox(height: 20),
                    if (baixando) ...[
                      LinearProgressIndicator(value: progresso),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          "${(progresso * 100).toStringAsFixed(0)}%",
                        ),
                      ),
                    ],
                    if (erro != null) ...[
                      Text(
                        erro!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!baixando)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text("Depois"),
                  ),
                FilledButton.icon(
                  icon: Icon(
                    baixando ? Icons.downloading : Icons.download,
                  ),
                  label: Text(
                    baixando ? "Baixando..." : "Atualizar",
                  ),
                  onPressed: baixando
                      ? null
                      : () async {
                          setState(() {
                            baixando = true;
                            erro = null;
                          });

                          try {
                            final arquivo = await service.baixarApk(
                              url: info.apkUrl,
                              nomeArquivo: info.nomeArquivo,
                              onProgress: (recebido, total) {
                                if (total > 0) {
                                  setState(() {
                                    progresso = recebido / total;
                                  });
                                }
                              },
                            );

                            if (!dialogContext.mounted) return;

                            final resultado = await OpenFilex.open(arquivo.path);

                            if (!dialogContext.mounted) return;

                            if (resultado.type != ResultType.done) {
                              setState(() {
                                baixando = false;
                                erro = resultado.type == ResultType.permissionDenied
                                    ? "Permissão negada. Vá em Configurações > Apps > "
                                          "Baixa Fácil > \"Instalar apps desconhecidos\" "
                                          "e permita, depois toque em Atualizar de novo."
                                    : "Não foi possível abrir o instalador: "
                                          "${resultado.message}";
                              });
                              return;
                            }

                            Navigator.pop(dialogContext);
                          } catch (e) {
                            if (!dialogContext.mounted) return;

                            setState(() {
                              baixando = false;
                              erro = "Erro ao baixar atualização: $e";
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }
}