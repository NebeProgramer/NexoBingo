/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 */

package com.mycompany.virtual_bingo;

import com.mycompany.virtual_bingo.Nexus.NexusUI;
import com.mycompany.virtual_bingo.UI.CoffeeDialog;
import javax.swing.SwingUtilities;

/**
 * Punto de entrada del juego. Abre la ventana Nexo, donde el jugador
 * decide si crea o se une a una partida.
 *
 * IMPORTANTE: para que el Nexo funcione, el Broker
 * ({@link com.mycompany.virtual_bingo.Broker.BrokerServer}) debe estar
 * corriendo antes en la máquina indicada como "servidor central".
 *
 * @author andor
 */
public class Virtual_Bingo {

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            NexusUI nexus = new NexusUI();
            nexus.setVisible(true);
            CoffeeDialog.maybeShow(nexus);
        });
    }
}
