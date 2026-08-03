/*
 * Interfaz remota del Broker: el "nexo" real entre servidor y cliente.
 *
 * CAMBIO IMPORTANTE de diseño: ahora la partida (Game) YA NO vive en la
 * máquina de quien la crea — vive en la misma máquina que el Broker (la
 * única que necesita ser públicamente alcanzable). Así, para jugar entre
 * redes distintas, solo esa máquina necesita IP pública/puerto abierto;
 * anfitriones y jugadores solo hacen conexiones salientes hacia ella.
 *
 * Como el Broker es ahora el único que crea códigos, ya no hace falta el
 * paso de "proponer un código y confirmarlo" (con su posible colisión):
 * el propio createGame() reserva el código de forma atómica en el mismo
 * momento en que crea el Game. El enum GameCodeStatus se sigue usando
 * igual para controlar el ciclo de vida de cada código:
 * HOSTED (sala abierta, acepta jugadores) <-> IN_GAME (ronda en curso,
 * no se aceptan nuevos jugadores) -> liberado (código vuelve a quedar
 * disponible cuando el anfitrión cierra la sala).
 */
package com.mycompany.virtual_bingo.Broker;

import com.mycompany.virtual_bingo.RMI.BingoService;
import java.rmi.Remote;
import java.rmi.RemoteException;

public interface BingoBroker extends Remote {

    /**
     * Crea una partida nueva en la máquina del Broker, con un código de
     * 6 dígitos único garantizado, y la deja en estado HOSTED.
     */
    HostedGame createGame() throws RemoteException;

    /**
     * Un cliente intenta unirse con un código. Solo funciona si el
     * código está en estado HOSTED.
     *
     * @throws GameNotAvailableException si el código no existe o ya
     *         está IN_GAME.
     */
    BingoService joinGame(String code) throws RemoteException, GameNotAvailableException;

    /** Cambia el estado de un código ya creado (HOSTED <-> IN_GAME). */
    void updateStatus(String code, GameCodeStatus status) throws RemoteException;

    /** Libera el código por completo (el anfitrión cerró la sala). */
    void releaseGame(String code) throws RemoteException;
}
