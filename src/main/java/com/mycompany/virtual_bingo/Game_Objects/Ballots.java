/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.virtual_bingo.Game_Objects;

import java.io.Serializable;

/**
 * IMPORTANTE: debe implementar Serializable porque viaja por RMI:
 * dentro de un {@code Tables} (que ya es Serializable) y también como
 * parámetro suelto en {@code BingoClientCallback#onBallotDrawn}.
 *
 * @author andor
 */
public class Ballots implements Serializable {

    private static final long serialVersionUID = 1L;

    String Letter;
    int Number;
    Status status;
    public enum Status{
        Used,
        Unused
    }

    public Ballots(String Letter, int Number) {
        this.Letter = Letter;
        this.Number = Number;
        this.status = Status.Unused;
    }

    public String getBallot(){
        return Letter + Number;
    }

    public String getLetter() {
        return Letter;
    }

    public int getNumber() {
        return Number;
    }

    public Status getStatus() {
        return status;
    }

    public void usedBallot(){
        this.status = Status.Used;
    }

    public void unusedBallot(){
        this.status = Status.Unused;
    }

    @Override
    public String toString(){
        if(this.status == Status.Used){
            // Muestra el número tachado para no perder la información
            return "X-" + Letter + Number + "-X";
        }
        if ("ID".equals(Letter)) {
            return "ID:" + String.format("%03d", Number);
        } else {
            return Letter + Number;
        }
    }
}
