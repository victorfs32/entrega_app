package com.example.entrega_app

import android.accessibilityservice.AccessibilityService
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Lê os textos da tela de OUTRO app (escolhido pelo motorista, ex.: Circuit)
 * enquanto a leitura está ligada. Não lê nenhum app além do escolhido, não
 * toca em nada e não guarda nada fora do aparelho: as telas lidas ficam em
 * memória até o Baixa Fácil buscá-las.
 */
class LeitorTelaService : AccessibilityService() {

    private val principal = Handler(Looper.getMainLooper())
    private val aoLer = Runnable { lerTela() }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instancia = this
    }

    override fun onAccessibilityEvent(evento: AccessibilityEvent?) {
        if (!capturando) return

        val alvo = pacoteAlvo
        if (alvo.isEmpty() || evento?.packageName?.toString() != alvo) return

        // A tela dispara muitos eventos seguidos ao rolar; lê só a última.
        principal.removeCallbacks(aoLer)
        principal.postDelayed(aoLer, 250)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        if (instancia === this) instancia = null
        principal.removeCallbacks(aoLer)
        super.onDestroy()
    }

    private fun lerTela() {
        val raiz = rootInActiveWindow ?: return

        try {
            if (raiz.packageName?.toString() != pacoteAlvo) return

            val itens = ArrayList<Item>()
            coletar(raiz, itens, 0)
            if (itens.isEmpty()) return

            // Ordem de leitura: de cima pra baixo, da esquerda pra direita.
            itens.sortWith(compareBy<Item>({ it.topo / 12 }, { it.esquerda }))

            // Cada texto vai com a posição na tela (topo, esquerda, base,
            // direita): é o que permite separar as linhas de uma lista.
            val linhas = itens
                .distinctBy { Triple(it.texto, it.topo, it.esquerda) }
                .map { listOf<Any>(it.texto, it.topo, it.esquerda, it.base, it.direita) }
            guardar(linhas)
        } catch (_: Exception) {
            // Tela mudou no meio da leitura; a próxima captura pega.
        }
    }

    private fun coletar(no: AccessibilityNodeInfo?, saida: MutableList<Item>, nivel: Int) {
        if (no == null || nivel > 60) return

        val texto = (no.text ?: no.contentDescription)?.toString()?.trim()

        if (!texto.isNullOrEmpty() && no.isVisibleToUser) {
            val area = Rect()
            no.getBoundsInScreen(area)
            saida.add(Item(texto, area.top, area.left, area.bottom, area.right))
        }

        for (i in 0 until no.childCount) {
            coletar(no.getChild(i), saida, nivel + 1)
        }
    }

    private class Item(
        val texto: String,
        val topo: Int,
        val esquerda: Int,
        val base: Int,
        val direita: Int
    )

    companion object {
        @Volatile var instancia: LeitorTelaService? = null
        @Volatile var capturando: Boolean = false
        @Volatile var pacoteAlvo: String = ""

        private const val MAXIMO_TELAS = 600
        private val telas = ArrayList<List<List<Any>>>()
        private val vistas = HashSet<Int>()

        @Synchronized
        fun guardar(linhas: List<List<Any>>) {
            // Mesma tela lida de novo (ex.: parado sem rolar) não entra duas vezes.
            if (!vistas.add(linhas.hashCode())) return
            if (telas.size >= MAXIMO_TELAS) telas.removeAt(0)
            telas.add(linhas)
        }

        /** Devolve as telas lidas desde a última busca e esvazia a fila. */
        @Synchronized
        fun retirar(): List<List<List<Any>>> {
            val copia = ArrayList(telas)
            telas.clear()
            vistas.clear()
            return copia
        }
    }
}
