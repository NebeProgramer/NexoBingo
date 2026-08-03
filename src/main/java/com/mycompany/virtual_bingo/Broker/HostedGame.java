/*
 * Paquete simple que el Broker devuelve al anfitrión al crear una sala:
 * el código de 6 dígitos y la referencia remota (stub) del Game recién
 * creado en la máquina del Broker.
 */
package com.mycompany.virtual_bingo.Broker;

import com.mycompany.virtual_bingo.RMI.BingoService;
import java.io.Serializable;

public final class HostedGame implements Serializable {

    private final String code;
    private final BingoService service;

    public HostedGame(String code, BingoService service) {
        this.code = code;
        this.service = service;
    }

    public String getCode() {
        return code;
    }

    public BingoService getService() {
        return service;
    }
}
