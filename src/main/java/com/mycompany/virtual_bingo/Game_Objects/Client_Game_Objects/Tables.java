/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.virtual_bingo.Game_Objects.Client_Game_Objects;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;

import com.mycompany.virtual_bingo.Game_Objects.Ballots;

public class Tables implements Serializable {

    // Es una buena práctica añadir un serialVersionUID cuando se implementa Serializable
    private static final long serialVersionUID = 1L;

    int table_id;
    Ballots[][] Table = new Ballots[5][5];

    public Tables(int table_id) {
        this.table_id = table_id;
        final String[] BINGO_LETTERS = {"B", "I", "N", "G", "O"};

        for (int i = 0; i < 5; i++) {
            String letter = BINGO_LETTERS[i];
            int startRange = (i * 15) + 1;

            List<Integer> columnNumbers = new ArrayList<>();
            for (int k = 0; k < 15; k++) {
                columnNumbers.add(startRange + k);
            }

            Collections.shuffle(columnNumbers);

            for (int j = 0; j < 5; j++) {
                if (i == 2 && j == 2) {
                    Table[i][j] = new Ballots("ID", table_id);
                } else {
                    int number = columnNumbers.get(j);
                    Table[i][j] = new Ballots(letter, number);

                    }
                }
        }
    }

    public void printTable() {
        for (int i = 0; i < 5; i++) {
            for (int j = 0; j < 5; j++) {
                System.out.printf("%-7s | ", Table[j][i].toString()); // Formato para alinear columnas
            }
            System.out.println();
        }
    }

    public Ballots[][] getTable() {
        return Table;
    }

    public int getTable_id() {
        return table_id;
    }

    public void usedBallot(int i, int j) {
        Table[i][j].usedBallot();
    }

    public void unusedBallot(int i, int j) {
        Table[i][j].unusedBallot();
    }

    /**
     * Verifica si el cartón es ganador (todas las casillas marcadas).
     * Esta es una validación del lado del cliente/objeto, asumiendo que las marcas son correctas.
     * La validación final contra las balotas cantadas la hace el servidor.
     * @return true si todas las casillas (excepto ID) están marcadas, false en caso contrario.
     */
    public boolean isWinner(){
        int ballots_Unused = 0;
        for(int i = 0; i < 5; i++){
            for(int j = 0; j < 5; j++){
                // La casilla de ID no cuenta para el bingo
                if(!Table[i][j].getLetter().equals("ID") && Table[i][j].getStatus() == Ballots.Status.Unused){
                    ballots_Unused++;
                }
            }
        }
        return ballots_Unused == 0;
    }

    /**
     * Validación AUTORITATIVA de victoria, pensada para el servidor.
     *
     * El servidor guarda su propia copia de {@code Tables} por jugador, y esa
     * copia nunca se marca (el cliente marca su propia copia serializada, que
     * es un objeto distinto). Por eso, en vez de confiar en el estado interno
     * de {@code Ballots.Status}, este método compara directamente los números
     * del cartón contra el conjunto de balotas que el servidor ya cantó.
     *
     * @param calledNumbers números que el servidor ya ha cantado
     * @return true si todas las casillas (excepto ID) ya fueron cantadas
     */
    public boolean isWinner(Set<Integer> calledNumbers) {
        for (int i = 0; i < 5; i++) {
            for (int j = 0; j < 5; j++) {
                Ballots b = Table[i][j];
                if ("ID".equals(b.getLetter())) {
                    continue;
                }
                if (!calledNumbers.contains(b.getNumber())) {
                    return false;
                }
            }
        }
        return true;
    }

    /**
     * Busca una balota en el cartón por su número y la marca como usada si la encuentra.
     * La casilla central (ID) y la casilla libre (N-centro) se marcan por defecto.
     * @param drawnBallot La balota que se cantó.
     * @return true si la balota estaba en el cartón y fue marcada, false en caso contrario.
     */
    public boolean markBallot(Ballots drawnBallot) {
        for (int i = 0; i < 5; i++) {
            for (int j = 0; j < 5; j++) {
                // No se puede marcar la casilla del ID
                if (Table[i][j].getLetter().equals("ID")) {
                    continue;
                }
                if (Table[i][j].getNumber() == drawnBallot.getNumber()) {
                    Table[i][j].usedBallot();
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Compara este cartón con un arreglo de otros cartones para ver si existe un duplicado.
     * @param otherTables El arreglo de cartones con los que se quiere comparar.
     * @return true si este cartón es idéntico a alguno en el arreglo, false en caso contrario.
     */
    public boolean isDuplicateIn(Tables[] otherTables) {
        for (Tables other : otherTables) {
            // Nos aseguramos de no comparar un cartón consigo mismo y que el objeto no sea nulo.
            if (other == null || this == other) {
                continue;
            }
            // Si encontramos uno idéntico, retornamos true inmediatamente.
            if (this.isIdenticalTo(other)) {
                return true;
            }
        }
        // Si terminamos el bucle sin encontrar duplicados, retornamos false.
        return false;
    }

    /**
     * Compara si este cartón es idéntico a otro, celda por celda.
     * @param otherTable El otro cartón a comparar.
     * @return true si todos los números en las mismas posiciones coinciden, false en caso contrario.
     */
    public boolean isIdenticalTo(Tables otherTable) {
        for (int i = 0; i < 5; i++) {
            for (int j = 0; j < 5; j++) {
                // Comparamos el número de la balota en cada posición.
                // La casilla central (ID) no necesita una comparación especial, ya que si los otros 24 números son iguales, las tablas son idénticas.
                if (this.Table[i][j].getNumber() != otherTable.Table[i][j].getNumber()) {
                    return false; // Si un solo número es diferente, los cartones no son idénticos.
                }
            }
        }
        return true; // Si todos los números coinciden, los cartones son idénticos.
    }

}
