/*
 * Interfaz remota del cliente (callback).
 * El servidor la usa para "empujar" (push) información hacia el cliente,
 * sin que el cliente tenga que estar preguntando (polling).
 */
package com.mycompany.virtual_bingo.RMI;

import com.mycompany.virtual_bingo.Game_Objects.Ballots;
import com.mycompany.virtual_bingo.Game_Objects.Client_Game_Objects.Tables;
import java.rmi.Remote;
import java.rmi.RemoteException;

/**
 * Contrato remoto implementado por el cliente. El servidor guarda una
 * referencia a esta interfaz por cada jugador registrado y la usa para
 * notificar eventos de la partida en tiempo real.
 *
 * @author andor
 */
public interface BingoClientCallback extends Remote {

    /**
     * Confirma el registro del jugador. En este punto el cliente todavía
     * NO tiene su cartón: solo sabe que quedó en la partida.
     */
    void onRegistrationConfirmed(String message) throws RemoteException;

    /**
     * Se invoca UNA sola vez, cuando el servidor da inicio al juego.
     * Este es el único momento en que el cliente recibe su cartón.
     *
     * @param assignedTable el cartón generado para este jugador
     */
    void onGameStarted(Tables assignedTable) throws RemoteException;

    /**
     * Se invoca cada vez que el servidor canta una nueva balota.
     */
    void onBallotDrawn(Ballots ballot) throws RemoteException;

    /**
     * Notifica al cliente que un cartón (posiblemente el suyo) ganó.
     *
     * @param winnerTableId id del cartón ganador
     */
    void onVictory(int winnerTableId) throws RemoteException;

    /**
     * Notifica el cierre de la partida.
     */
    void onGameEnded(String message) throws RemoteException;

    /**
     * Notificación genérica (avisos, errores de validación como un BINGO
     * falso, etc). No implica ni el inicio ni el cierre de la partida.
     */
    void onMessage(String message) throws RemoteException;
}
