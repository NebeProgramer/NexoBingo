/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.virtual_bingo.Server;

import java.rmi.RemoteException;
import java.rmi.registry.LocateRegistry;
import java.rmi.registry.Registry;
import java.rmi.server.UnicastRemoteObject;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Scanner;
import java.util.Set;

import com.mycompany.virtual_bingo.Game_Objects.Ballots;
import com.mycompany.virtual_bingo.Game_Objects.Client_Game_Objects.Tables;
import com.mycompany.virtual_bingo.Game_Objects.Server_Game_Objects.Board;
import com.mycompany.virtual_bingo.RMI.BingoService;
import com.mycompany.virtual_bingo.RMI.ClientState;
import com.mycompany.virtual_bingo.RMI.RegistrationResult;

/**
 * Servidor de Bingo.
 *
 * Regla de negocio clave: cuando un jugador se registra, el servidor YA genera
 * su cartón internamente (para poder validar duplicados), pero NO se lo envía.
 * El cartón se retiene en {@link PlayerSession} y solo se entrega (a través de
 * {@link #pollState}) cuando el juego ya inició.
 *
 * CAMBIO DE DISEÑO: ya no hay callbacks push hacia los clientes (ver nota en
 * {@link BingoService}). Todo cliente se entera de los cambios llamando
 * {@link #pollState} periódicamente.
 *
 * @author andor
 */
public class Game extends UnicastRemoteObject implements BingoService, BingoHostControl {

    /**
     * Puerto fijo en el que se exporta cada partida (y también el Broker
     * y su registro). Usar siempre el mismo puerto es clave para poder
     * jugar entre redes distintas: solo hay que abrir/redirigir UN puerto
     * en el router o firewall, en vez de uno distinto por cada objeto
     * remoto exportado (que es lo que pasa si se usa el puerto anónimo 0).
     */
    public static final int RMI_PORT = 1099;

    private final List<PlayerSession> players = new ArrayList<>();
    private Board board = new Board();
    private boolean gameStarted = false;
    private final List<Tables> victoryTables = new ArrayList<>();
    private final Set<Integer> calledNumbers = new HashSet<>();
    private final List<String> calledLog = new ArrayList<>();

    // Identifica la ronda actual; se incrementa cada vez que endGame()
    // prepara la siguiente. Es lo que le permite al cliente (por polling)
    // distinguir "seguimos en la misma ronda" de "hay que limpiar todo y
    // esperar de nuevo", sin importar si el cierre fue manual o por BINGO.
    private int roundId = 0;

    // Se guardan aparte del resto del estado de la ronda (que sí se
    // limpia en endGame) para darle al cliente una ventana real donde
    // pueda enterarse de quién ganó antes de que ya se haya preparado la
    // ronda siguiente.
    private volatile int lastWinnerTableId = -1;
    private volatile int lastWinnerRoundId = -1;

    // Hook opcional para que una UI (GameServerUI) se entere de cambios
    // de estado sin tener que hacer polling — solo sirve cuando Game vive
    // en el MISMO proceso que la UI (modo legado de una sola máquina).
    private Runnable onStateChanged = () -> { };

    public Game() throws RemoteException {
        super(RMI_PORT);
    }

    public void setOnStateChangedListener(Runnable listener) {
        this.onStateChanged = (listener != null) ? listener : () -> { };
    }

    private void notifyStateChanged() {
        onStateChanged.run();
    }

    // ---- Getters de solo lectura para la UI del servidor (BingoHostControl) ----

    @Override
    public synchronized List<String> getPlayerNames() throws RemoteException {
        List<String> names = new ArrayList<>();
        for (PlayerSession p : players) {
            names.add(p.getPlayerName() + " (Cartón #" + p.getTable().getTable_id() + ")");
        }
        return names;
    }

    @Override
    public boolean isGameStarted() throws RemoteException {
        return gameStarted;
    }

    @Override
    public synchronized int getCalledCount() throws RemoteException {
        return calledNumbers.size();
    }

    @Override
    public synchronized List<String> getCalledBallotsDisplay() throws RemoteException {
        return new ArrayList<>(calledLog);
    }

    // ---- BingoService: lo que usa el cliente/jugador ----

    @Override
    public synchronized RegistrationResult registerPlayer(String playerName) throws RemoteException {
        if (gameStarted) {
            return new RegistrationResult(false, -1, "La partida ya inició, no puedes registrarte ahora.");
        }

        System.out.println("Petición de registro del jugador: " + playerName);

        // Generar un ID aleatorio y único para el nuevo cartón
        int randomId;
        boolean isIdInUse;
        do {
            isIdInUse = false;
            randomId = 100 + (int) (Math.random() * 900); // ID aleatorio entre 100 y 999
            for (PlayerSession p : players) {
                if (p.getTable().getTable_id() == randomId) {
                    isIdInUse = true;
                    break;
                }
            }
        } while (isIdInUse);

        Tables newTable;
        Tables[] existingTables = players.stream().map(PlayerSession::getTable).toArray(Tables[]::new);

        do {
            newTable = new Tables(randomId);
        } while (newTable.isDuplicateIn(existingTables));

        players.add(new PlayerSession(playerName, newTable));
        System.out.println("Cartón #" + newTable.getTable_id() + " reservado para " + playerName
                + " (retenido hasta que inicie el juego)");

        notifyStateChanged();
        return new RegistrationResult(true, newTable.getTable_id(),
                "Registro exitoso. Espera a que el anfitrión inicie la partida.");
    }

    @Override
    public synchronized void startGame() throws RemoteException {
        if (gameStarted) {
            System.out.println("El juego ya había iniciado.");
            return;
        }
        if (players.isEmpty()) {
            System.out.println("No hay jugadores registrados, no se puede iniciar.");
            return;
        }

        gameStarted = true;
        System.out.println("Game started. " + players.size() + " jugador(es) ya pueden ver su cartón por polling.");
        notifyStateChanged();
    }

    @Override
    public synchronized Ballots drawNextBallot() throws RemoteException {
        if (!gameStarted) {
            System.out.println("No se puede cantar balotas: el juego no ha iniciado.");
            return null;
        }

        Ballots ballot = board.drawRandomUnused();
        if (ballot == null) {
            System.out.println("No quedan más balotas por cantar.");
            return null;
        }
        calledNumbers.add(ballot.getNumber());
        calledLog.add(ballot.getLetter() + "-" + ballot.getNumber());

        System.out.println("Balota cantada: " + ballot.getBallot());
        notifyStateChanged();
        // Se devuelve la balota (y no solo void) para que quien la pidió se
        // entere por esta misma respuesta, sin esperar a su propio poll.
        // Ver el javadoc de BingoService#drawNextBallot para el porqué.
        return ballot;
    }

    @Override
    public synchronized String singBingo(int tableId) throws RemoteException {
        PlayerSession singingPlayer = players.stream()
                .filter(p -> p.getTable().getTable_id() == tableId)
                .findFirst()
                .orElse(null);

        if (singingPlayer == null) {
            System.out.println("Se recibió un canto de BINGO para un cartón no registrado: " + tableId);
            return "No se encontró tu cartón en esta partida.";
        }

        System.out.println("¡Jugador " + singingPlayer.getPlayerName() + " (Cartón #" + tableId + ") canta BINGO! Validando...");

        // 1. Validar el cartón del jugador que cantó, contra las balotas que
        // el SERVIDOR realmente ha cantado (nunca contra el estado marcado
        // del lado del cliente, que es una copia serializada aparte).
        Tables playerTable = singingPlayer.getTable();
        boolean isLegitWinner = playerTable.isWinner(calledNumbers);

        if (!isLegitWinner) {
            System.out.println("BINGO FALSO para el cartón #" + tableId + ". El juego continúa.");
            return "Tu BINGO es incorrecto. El juego continúa.";
        }

        System.out.println("¡BINGO VÁLIDO para el cartón #" + tableId + "!");
        victoryTables.add(playerTable); // Añadir a la lista de ganadores de esta ronda

        // 2. Buscar si hay otros ganadores simultáneos
        for (PlayerSession otherPlayer : players) {
            if (otherPlayer.getTable().getTable_id() == tableId) continue; // Ya lo procesamos
            if (otherPlayer.getTable().isWinner(calledNumbers)) {
                System.out.println("¡El cartón #" + otherPlayer.getTable().getTable_id() + " también tiene BINGO!");
                victoryTables.add(otherPlayer.getTable());
            }
        }

        // 3. Determinar el ganador final
        Tables finalWinner = victoryTables.stream()
                .min((t1, t2) -> Integer.compare(t1.getTable_id(), t2.getTable_id()))
                .get(); // Siempre habrá al menos un ganador en este punto

        System.out.println("El ganador final es el cartón #" + finalWinner.getTable_id() + " (ID más bajo).");

        lastWinnerTableId = finalWinner.getTable_id();
        lastWinnerRoundId = roundId;
        boolean iWon = finalWinner.getTable_id() == tableId;
        String resultMessage = iWon
                ? "¡Ganaste! Cartón #" + finalWinner.getTable_id()
                : "Ganó el cartón #" + finalWinner.getTable_id();

        notifyStateChanged();

        // Un BINGO válido también cierra la ronda actual: reutilizamos la
        // misma lógica que dispara el botón "Finalizar partida".
        endGame();

        return resultMessage;
    }

    /**
     * Se dispara con el botón "Finalizar partida" (o automáticamente tras un
     * BINGO válido, ver {@link #singBingo}). Cierra la ronda actual y deja
     * todo listo para la siguiente SIN apagar el servidor:
     * <ol>
     *   <li>Reactiva "Iniciar partida".</li>
     *   <li>Crea una bolsa de balotas nueva, con las 75 sin descubrir.</li>
     *   <li>Reparte cartones nuevos a los jugadores ya registrados (se
     *       retienen hasta el próximo startGame(), igual que al conectarse).</li>
     *   <li>Incrementa {@code roundId}, la señal que usan los clientes (por
     *       polling) para darse cuenta de que deben limpiar su cartón.</li>
     * </ol>
     */
    @Override
    public synchronized void endGame() throws RemoteException {
        System.out.println("Finalizando la partida. Preparando la siguiente ronda...");

        gameStarted = false;
        calledNumbers.clear();
        calledLog.clear();
        board = new Board(); // Bolsa nueva con las 75 balotas sin descubrir
        victoryTables.clear();
        roundId++;

        // Reparte cartones nuevos a los jugadores ya registrados. Se
        // retienen (no se muestran) hasta el próximo startGame().
        for (PlayerSession session : players) {
            Tables newTable;
            Tables[] existingTables = players.stream().map(PlayerSession::getTable).toArray(Tables[]::new);
            do {
                newTable = new Tables(session.getTable().getTable_id()); // conserva el mismo ID
            } while (newTable.isDuplicateIn(existingTables));

            session.setTable(newTable);
            System.out.println("Nuevo cartón #" + newTable.getTable_id() + " reservado para " + session.getPlayerName()
                    + " (retenido hasta la próxima partida)");
        }

        notifyStateChanged();
    }

    @Override
    public synchronized ClientState pollState(int tableId) throws RemoteException {
        PlayerSession session = players.stream()
                .filter(p -> p.getTable().getTable_id() == tableId)
                .findFirst()
                .orElse(null);

        Tables table = (session != null && gameStarted) ? session.getTable() : null;

        return new ClientState(roundId, gameStarted, table,
                new ArrayList<>(calledLog), lastWinnerTableId, lastWinnerRoundId);
    }

    public static void main(String[] args) {
        try {
            // Iniciar el registro RMI en el puerto 1099
            Registry registry = LocateRegistry.createRegistry(1099);

            // Crear una instancia del servidor y registrarla
            Game bingoServer = new Game();
            registry.rebind("BingoService", bingoServer);

            System.out.println("Servidor de Bingo listo y esperando clientes...");

            // Habilitar comandos en la instancia correcta del servidor
            System.out.println("Comandos disponibles: start, draw, end, quit");
            Scanner scanner = new Scanner(System.in);
            while (true) {
                String command = scanner.nextLine();
                try {
                    switch (command.toLowerCase()) {
                        case "start" -> bingoServer.startGame();
                        case "draw" -> bingoServer.drawNextBallot();
                        case "end" -> bingoServer.endGame(); // termina la ronda y prepara la siguiente
                        case "quit" -> {
                            UnicastRemoteObject.unexportObject(bingoServer, true);
                            System.exit(0);
                        }
                        default -> System.out.println("Comando no reconocido. Comandos disponibles: start, draw, end, quit");
                    }
                } catch (RemoteException e) {
                    System.err.println("Error en el comando: " + e.getMessage());
                }
            }
        } catch (Exception e) {
            System.err.println("Excepción en el servidor: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
