/*
 * Interfaz remota del servidor de Bingo.
 * Todo lo que el cliente puede invocar sobre el servidor pasa por aquí.
 *
 * CAMBIO DE DISEÑO: ya no existe callback del cliente hacia el servidor.
 * Antes, registerPlayer recibía un BingoClientCallback para que el
 * servidor le "empujara" eventos al cliente (cartón, balotas, victoria).
 * Eso requiere que el SERVIDOR pueda conectarse DE VUELTA al cliente —
 * imposible si el cliente está detrás de un router doméstico sin puertos
 * abiertos (el caso normal de cualquier jugador real). Ahora todo es
 * "pull": el cliente pregunta (pollState) tan seguido como quiere, y
 * nunca necesita ser alcanzable desde afuera.
 *
 * @author andor
 */
package com.mycompany.virtual_bingo.RMI;

import java.rmi.Remote;
import java.rmi.RemoteException;

public interface BingoService extends Remote {

    /**
     * Registra a un jugador en la partida. El cartón (Tables) todavía NO
     * se entrega aquí (regla de negocio: se retiene hasta que inicie el
     * juego) — pero el ID del cartón sí, porque el cliente lo necesita
     * para poder llamar {@link #pollState} y {@link #singBingo} después.
     */
    RegistrationResult registerPlayer(String playerName) throws RemoteException;

    /** Da inicio a la partida: a partir de aquí pollState() ya incluye el cartón. */
    void startGame() throws RemoteException;

    /** Saca la siguiente balota del tablero. */
    void drawNextBallot() throws RemoteException;

    /**
     * Un jugador reclama BINGO. A diferencia del resto de eventos (que se
     * enteran por polling), la respuesta a ESTA llamada específica sí es
     * síncrona: el propio cliente que canta se entera al instante si fue
     * válido o no, sin esperar el próximo poll.
     *
     * @param tableId id del cartón que reclama la victoria
     * @return mensaje para mostrarle al jugador ("¡Ganaste!", "BINGO falso...")
     */
    String singBingo(int tableId) throws RemoteException;

    /** Finaliza la ronda actual y prepara la siguiente. */
    void endGame() throws RemoteException;

    /**
     * Punto único de consulta para el cliente: estado actual del juego
     * relevante para ESE cartón. Pensado para llamarse en un bucle cada
     * ~1 segundo desde {@code BingoClientUI}.
     */
    ClientState pollState(int tableId) throws RemoteException;
}
