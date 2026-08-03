/*
 * Implementación del Broker. Es un proceso propio que debe quedar
 * corriendo en la máquina "central" — la única que necesita IP pública o
 * puerto redirigido — ANTES de que nadie intente crear o unirse a una
 * sala. Cada partida (Game) se crea y vive AQUÍ, no en la máquina de
 * quien la solicita: así los anfitriones no necesitan abrir nada en su
 * propio router.
 */
package com.mycompany.virtual_bingo.Broker;

import com.mycompany.virtual_bingo.RMI.BingoService;
import com.mycompany.virtual_bingo.Server.Game;

import java.rmi.RemoteException;
import java.rmi.registry.LocateRegistry;
import java.rmi.registry.Registry;
import java.rmi.server.UnicastRemoteObject;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public class BrokerServer extends UnicastRemoteObject implements BingoBroker {

    /** Un renglón de la tabla de códigos que administra el Broker. */
    private static final class GameEntry {
        volatile GameCodeStatus status;
        final Game game;

        GameEntry(GameCodeStatus status, Game game) {
            this.status = status;
            this.game = game;
        }
    }

    private final Map<String, GameEntry> codes = new ConcurrentHashMap<>();

    public BrokerServer() throws RemoteException {
        super(Game.RMI_PORT);
    }

    @Override
    public synchronized HostedGame createGame() throws RemoteException {
        String code;
        do {
            code = String.format("%06d", (int) (Math.random() * 1_000_000));
        } while (codes.containsKey(code));

        Game game = new Game(); // se exporta en Game.RMI_PORT, mismo puerto que el Broker
        codes.put(code, new GameEntry(GameCodeStatus.HOSTED, game));
        System.out.println("[Broker] Sala creada -> código " + code + " (HOSTED).");
        return new HostedGame(code, game);
    }

    @Override
    public BingoService joinGame(String code) throws RemoteException, GameNotAvailableException {
        GameEntry entry = codes.get(code);
        if (entry == null) {
            throw new GameNotAvailableException("Ese código no corresponde a ninguna sala abierta.");
        }
        if (entry.status == GameCodeStatus.IN_GAME) {
            throw new GameNotAvailableException("Esa partida ya está en juego. Espera a que termine la ronda.");
        }
        System.out.println("[Broker] Código " + code + " entregado a un cliente que se une.");
        return entry.game;
    }

    @Override
    public void updateStatus(String code, GameCodeStatus status) throws RemoteException {
        GameEntry entry = codes.get(code);
        if (entry == null) {
            return;
        }
        entry.status = status;
        System.out.println("[Broker] Código " + code + " -> " + status);
    }

    @Override
    public synchronized void releaseGame(String code) throws RemoteException {
        GameEntry entry = codes.remove(code);
        if (entry != null) {
            try {
                UnicastRemoteObject.unexportObject(entry.game, true);
            } catch (Exception ex) {
                System.err.println("No se pudo des-exportar la partida " + code + ": " + ex.getMessage());
            }
        }
        System.out.println("[Broker] Código " + code + " liberado.");
    }

    public static void main(String[] args) {
        try {
            // OJO para jugar entre redes distintas: exporta esta JVM con
            // -Djava.rmi.server.hostname=<IP publica o dominio de esta
            // maquina>, para que los stubs que reparte el Broker (y los
            // Game que crea) lleven esa dirección en vez de una IP
            // privada. Además hay que abrir/redirigir el puerto TCP
            // Game.RMI_PORT (1099) hacia esta máquina.
            Registry registry = LocateRegistry.createRegistry(Game.RMI_PORT);
            BrokerServer broker = new BrokerServer();
            registry.rebind("BingoBroker", broker);
            System.out.println("Broker de Bingo listo en el puerto " + Game.RMI_PORT
                    + ", esperando anfitriones y clientes...");
        } catch (Exception e) {
            System.err.println("Excepción en el Broker: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
