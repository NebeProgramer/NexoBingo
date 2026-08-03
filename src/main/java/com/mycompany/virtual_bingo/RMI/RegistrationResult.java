/*
 * Respuesta síncrona a registerPlayer(): reemplaza al viejo callback
 * onRegistrationConfirmed. Le dice al cliente si quedó registrado y, si
 * fue así, con qué número de cartón (lo necesita para el resto de las
 * llamadas: pollState(tableId), singBingo(tableId)).
 */
package com.mycompany.virtual_bingo.RMI;

import java.io.Serializable;

public final class RegistrationResult implements Serializable {

    private final boolean accepted;
    private final int tableId; // -1 si accepted == false
    private final String message;

    public RegistrationResult(boolean accepted, int tableId, String message) {
        this.accepted = accepted;
        this.tableId = tableId;
        this.message = message;
    }

    public boolean isAccepted() {
        return accepted;
    }

    public int getTableId() {
        return tableId;
    }

    public String getMessage() {
        return message;
    }
}
