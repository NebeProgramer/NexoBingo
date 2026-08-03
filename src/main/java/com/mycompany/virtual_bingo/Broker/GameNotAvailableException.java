/*
 * Excepción de negocio: se lanza cuando un cliente intenta unirse con un
 * código que no está en estado HOSTED (no existe, o ya está IN_GAME).
 */
package com.mycompany.virtual_bingo.Broker;

public class GameNotAvailableException extends Exception {

    public GameNotAvailableException(String message) {
        super(message);
    }
}
