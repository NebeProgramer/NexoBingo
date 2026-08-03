/*
 * Interfaz remota "de administrador". Separada de BingoService a propósito:
 * BingoService es lo que ve un JUGADOR (registrarse, cantar bingo...);
 * BingoHostControl es lo que necesita el PANEL DEL ANFITRIÓN para pintarse
 * (lista de jugadores, si ya inició, cuántas balotas van) sin exponerle
 * esos métodos a los clientes normales.
 *
 * Game implementa ambas interfaces, así que el mismo stub remoto sirve
 * para las dos cosas (se castea según quién lo use).
 */
package com.mycompany.virtual_bingo.Server;

import java.rmi.Remote;
import java.rmi.RemoteException;
import java.util.List;

public interface BingoHostControl extends Remote {

    /** Nombres de jugadores registrados, con su número de cartón. */
    List<String> getPlayerNames() throws RemoteException;

    boolean isGameStarted() throws RemoteException;

    int getCalledCount() throws RemoteException;

    /**
     * Historial de balotas cantadas en esta ronda, en orden, ya
     * formateadas ("B-12", "N-41", ...) para pintarlas directo en el log
     * del panel del anfitrión sin depender de System.out (que ahora corre
     * en la máquina del Broker, no en la del anfitrión).
     */
    List<String> getCalledBallotsDisplay() throws RemoteException;
}
