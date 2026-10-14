package com.example.entrega_app

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ponte com o LeitorTelaService (leitura da tela de outro app).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "baixafacil/leitor_tela")
            .setMethodCallHandler { chamada, resultado ->
                when (chamada.method) {
                    "servicoAtivo" -> resultado.success(servicoAtivo())

                    "abrirAcessibilidade" -> {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        resultado.success(null)
                    }

                    "abrirDetalhesDoApp" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        resultado.success(null)
                    }

                    "listarApps" -> {
                        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                        val apps = packageManager.queryIntentActivities(intent, 0)
                            .filter { it.activityInfo.packageName != packageName }
                            .map {
                                mapOf(
                                    "nome" to it.loadLabel(packageManager).toString(),
                                    "pacote" to it.activityInfo.packageName
                                )
                            }
                            .distinctBy { it["pacote"] }
                            .sortedBy { (it["nome"] ?: "").lowercase() }
                        resultado.success(apps)
                    }

                    "definirAlvo" -> {
                        LeitorTelaService.pacoteAlvo = chamada.argument<String>("pacote") ?: ""
                        resultado.success(null)
                    }

                    "capturar" -> {
                        LeitorTelaService.capturando = chamada.argument<Boolean>("ligado") ?: false
                        resultado.success(null)
                    }

                    "retirarTelas" -> resultado.success(LeitorTelaService.retirar())

                    "abrirApp" -> {
                        val pacote = chamada.argument<String>("pacote") ?: ""
                        val intent = packageManager.getLaunchIntentForPackage(pacote)
                        if (intent == null) {
                            resultado.success(false)
                        } else {
                            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            resultado.success(true)
                        }
                    }

                    else -> resultado.notImplemented()
                }
            }
    }

    private fun servicoAtivo(): Boolean {
        val habilitados = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val meu = ComponentName(this, LeitorTelaService::class.java)

        return habilitados.split(':').any {
            ComponentName.unflattenFromString(it) == meu
        }
    }
}
