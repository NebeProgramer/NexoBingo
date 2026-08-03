/*
 * Estado de un código de partida de 6 dígitos dentro del Broker.
 *
 * NOTA: se usa UNOCCUPIED (no "UNOCUPED") e IN_GAME (no "IN-GAME"), porque
 * un identificador de Java no puede contener un guion medio; el guion se
 * interpretaría como una resta. Los valores del enum solicitado quedan así:
 *
 *   - UNOCCUPIED : el código fue generado como candidato, pero ningún
 *                  anfitrión lo ha confirmado todavía. Varios códigos
 *                  candidatos iguales pueden "solaparse" en distintas
 *                  ventanas de creación mientras estén en este estado.
 *   - HOSTED     : un anfitrión confirmó ese código; ya hay una partida
 *                  real (un objeto Game exportado) escuchando detrás.
 *                  Los clientes solo pueden unirse cuando el código está
 *                  en este estado.
 *   - IN_GAME    : el anfitrión ya inició la partida (Game#startGame()).
 *                  No se aceptan nuevos clientes hasta que la ronda
 *                  termine y el código vuelva a HOSTED.
 */
package com.mycompany.virtual_bingo.Broker;

public enum GameCodeStatus {
    UNOCCUPIED,
    HOSTED,
    IN_GAME
}
