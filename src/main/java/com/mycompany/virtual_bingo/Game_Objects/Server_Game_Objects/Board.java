/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.virtual_bingo.Game_Objects.Server_Game_Objects;

import com.mycompany.virtual_bingo.Game_Objects.Ballots;
import java.util.ArrayList;
import java.util.List;

/**
 * Bolsa de balotas del servidor (las 75 balotas del juego). Se usa para
 * "cantar" balotas al azar sin repetir, una vez que la partida inicia.
 *
 * @author andor
 */
public class Board {

    Ballots[][] Board = new Ballots[5][15];

    public Board() {
        for (int i = 0; i < 5; i++) {
            for (int j = 0; j < 15; j++) {
                // Rango de cada columna: B 1-15, I 16-30, N 31-45, G 46-60, O 61-75
                int number = (i * 15) + (j + 1);
                String Letter = "";
                switch (i) {
                    case 0 -> Letter = "B";
                    case 1 -> Letter = "I";
                    case 2 -> Letter = "N";
                    case 3 -> Letter = "G";
                    case 4 -> Letter = "O";
                }
                Board[i][j] = new Ballots(Letter, number);
            }
        }
    }

    public void printBoard() {
        for (int i = 0; i < 5; i++) {
            for (int j = 0; j < 15; j++) {
                System.out.print(Board[i][j].toString() + " | ");
            }
            System.out.println("-----");
        }
    }

    public void usedBallot(int i, int j) {
        Board[i][j].usedBallot();
    }

    public void unusedBallot(int i, int j) {
        Board[i][j].unusedBallot();
    }

    public Ballots[][] getBoard() {
        return Board;
    }

    /**
     * Saca al azar una balota que todavía no haya sido cantada y la marca
     * como usada. Pensado para ser invocado desde el servidor (Game) cada
     * vez que se quiera cantar una nueva balota a los clientes.
     *
     * @return la balota cantada, o {@code null} si ya no quedan balotas.
     */
    public synchronized Ballots drawRandomUnused() {
        List<Ballots> available = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            for (int j = 0; j < 15; j++) {
                if (Board[i][j].getStatus() == Ballots.Status.Unused) {
                    available.add(Board[i][j]);
                }
            }
        }
        if (available.isEmpty()) {
            return null;
        }
        Ballots chosen = available.get((int) (Math.random() * available.size()));
        chosen.usedBallot();
        return chosen;
    }
}
