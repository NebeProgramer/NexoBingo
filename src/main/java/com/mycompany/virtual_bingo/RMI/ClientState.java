/*
 * Snapshot que el cliente pide por RMI (poll) en vez de esperar que el
 * servidor lo llame (push). Un jugador detrás de un router doméstico
 * jamás es alcanzable desde afuera, así que aquí SIEMPRE es el cliente
 * quien inicia la conexión — nunca el servidor.
 *
 * roundId identifica la ronda actual: cambia cada vez que endGame()
 * prepara la siguiente. Si el cliente ve que roundId cambió desde su
 * último poll, sabe que debe limpiar su cartón/casillas marcadas y
 * esperar de nuevo — sin importar si el cierre fue manual o por un
 * BINGO válido.
 *
 * winnerTableId/winnerRoundId quedan registrados por separado y NO se
 * limpian junto con el resto del estado de la ronda, para darle al
 * cliente una ventana real donde pueda enterarse de quién ganó antes de
 * que el servidor ya haya preparado la ronda siguiente.
 */
package com.mycompany.virtual_bingo.RMI;

import com.mycompany.virtual_bingo.Game_Objects.Client_Game_Objects.Tables;
import java.io.Serializable;
import java.util.List;

public final class ClientState implements Serializable {

    private final int roundId;
    private final boolean gameStarted;
    private final Tables table; // null hasta que gameStarted == true
    private final List<String> calledBallotsDisplay;
    private final int winnerTableId; // -1 si nadie ha ganado todavía
    private final int winnerRoundId; // ronda en la que ocurrió ese triunfo

    public ClientState(int roundId, boolean gameStarted, Tables table,
            List<String> calledBallotsDisplay, int winnerTableId, int winnerRoundId) {
        this.roundId = roundId;
        this.gameStarted = gameStarted;
        this.table = table;
        this.calledBallotsDisplay = calledBallotsDisplay;
        this.winnerTableId = winnerTableId;
        this.winnerRoundId = winnerRoundId;
    }

    public int getRoundId() {
        return roundId;
    }

    public boolean isGameStarted() {
        return gameStarted;
    }

    public Tables getTable() {
        return table;
    }

    public List<String> getCalledBallotsDisplay() {
        return calledBallotsDisplay;
    }

    public int getWinnerTableId() {
        return winnerTableId;
    }

    public int getWinnerRoundId() {
        return winnerRoundId;
    }
}
