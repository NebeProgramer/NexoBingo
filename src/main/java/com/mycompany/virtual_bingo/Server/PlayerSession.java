/*
 * Estado que el servidor guarda de cada jugador conectado.
 * Esta clase NUNCA viaja por la red: vive solo del lado del servidor.
 */
package com.mycompany.virtual_bingo.Server;

import com.mycompany.virtual_bingo.Game_Objects.Client_Game_Objects.Tables;

/**
 * Representa a un jugador registrado en el servidor: su nombre y el
 * cartón que se le asignó (generado al registrarse, pero retenido hasta
 * que el juego inicie). Ya no guarda ningún callback remoto — el cliente
 * se entera de todo por polling (ver {@link BingoHostControl} / pollState
 * en {@link Game}), nunca por que el servidor lo llame de vuelta.
 *
 * @author andor
 */
public class PlayerSession {

    private final String playerName;
    private Tables table;

    public PlayerSession(String playerName, Tables table) {
        this.playerName = playerName;
        this.table = table;
    }

    public String getPlayerName() {
        return playerName;
    }

    public Tables getTable() {
        return table;
    }

    public void setTable(Tables table) {
        this.table = table;
    }
}
