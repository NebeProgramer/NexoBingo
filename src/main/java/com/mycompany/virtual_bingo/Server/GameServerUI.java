/*
 * Interfaz gráfica del servidor. Es un CONTROL REMOTO: desde la reforma
 * para jugar entre redes distintas, el objeto Game real vive en la
 * máquina del Broker, no aquí. Esta ventana solo llama por RMI a
 * startGame/drawNextBallot/endGame (BingoService) y hace polling de
 * getPlayerNames/isGameStarted/getCalledCount/getCalledBallotsDisplay
 * (BingoHostControl) para refrescarse — ya no hay un Runnable local que
 * la avise, porque el cambio de estado ocurre en otro proceso.
 */
package com.mycompany.virtual_bingo.Server;

import com.mycompany.virtual_bingo.Broker.BingoBroker;
import com.mycompany.virtual_bingo.Broker.GameCodeStatus;
import com.mycompany.virtual_bingo.RMI.BingoService;
import com.mycompany.virtual_bingo.UI.CardPanel;
import com.mycompany.virtual_bingo.UI.RoundButton;
import com.mycompany.virtual_bingo.UI.StyleKit;
import com.mycompany.virtual_bingo.UI.Theme;

import java.awt.BorderLayout;
import java.awt.GridLayout;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.util.List;

import javax.swing.BorderFactory;
import javax.swing.DefaultListModel;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JList;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.SwingUtilities;

/**
 * Panel de control remoto del anfitrión: ver jugadores conectados, iniciar
 * la partida (momento en el que los cartones se entregan), cantar balotas
 * una por una, y finalizar la partida.
 *
 * @author andor
 */
public class GameServerUI extends JFrame {

    private static final int POLL_MS = 800;

    private final BingoService service;
    private final BingoHostControl control;
    private final String code;
    private final BingoBroker broker;

    private volatile boolean polling = true;
    private int lastLoggedBallots = 0;

    private final DefaultListModel<String> playersModel = new DefaultListModel<>();
    private final JTextArea logArea = new JTextArea();
    private final JLabel statusLabel = new JLabel("Esperando jugadores...");

    private final RoundButton startButton = new RoundButton("▶  Iniciar juego", Theme.GREEN);
    private final RoundButton drawButton = new RoundButton("●  Cantar balota", Theme.BLUE);
    private final RoundButton endButton = new RoundButton("■  Finalizar partida", Theme.RED);

    /** Constructor legado: Game local, en el mismo proceso, sin Broker. */
    public GameServerUI(Game game) {
        this(game, null, null);
    }

    /**
     * Constructor usado por {@link com.mycompany.virtual_bingo.Nexus.NexusUI}
     * tras crear la sala en el Broker. {@code service} puede ser un objeto
     * local (modo legado) o un stub remoto (modo Broker) — Game implementa
     * tanto BingoService como BingoHostControl, así que el mismo objeto
     * sirve para las dos cosas.
     */
    public <T extends BingoService & BingoHostControl> GameServerUI(T service, String code, BingoBroker broker) {
        super("NexoBingo — Panel del anfitrión" + (code != null ? " · Código " + code : ""));
        this.service = service;
        this.control = service;
        this.code = code;
        this.broker = broker;

        com.mycompany.virtual_bingo.UI.Theme.applyAppIcon(this);

        buildUI();
        setupCloseBehavior();
        startPolling();
    }

    private void buildUI() {
        setDefaultCloseOperation(broker != null ? JFrame.DO_NOTHING_ON_CLOSE : JFrame.EXIT_ON_CLOSE);
        setSize(700, 520);
        setLocationRelativeTo(null);

        getContentPane().setBackground(Theme.BG_DARK);
        setLayout(new BorderLayout(0, 0));

        add(buildHeader(), BorderLayout.NORTH);
        add(buildCenter(), BorderLayout.CENTER);
        add(buildFooter(), BorderLayout.SOUTH);
    }

    private JPanel buildHeader() {
        JPanel header = new JPanel(new BorderLayout(0, 4));
        header.setOpaque(true);
        header.setBackground(Theme.BG_DARK);
        header.setBorder(BorderFactory.createEmptyBorder(20, 24, 12, 24));

        JLabel title = new JLabel("NexoBingo" + (code != null ? " - " + code : ""));
        title.setFont(Theme.TITLE_FONT);
        title.setForeground(Theme.GOLD);

        statusLabel.setFont(Theme.SUBTITLE_FONT);
        statusLabel.setForeground(Theme.TEXT_MUTED);

        header.add(title, BorderLayout.NORTH);
        header.add(statusLabel, BorderLayout.SOUTH);
        return header;
    }

    private JPanel buildCenter() {
        JPanel center = new JPanel(new GridLayout(1, 2, 16, 0));
        center.setOpaque(false);
        center.setBorder(BorderFactory.createEmptyBorder(0, 24, 0, 24));

        JList<String> playerList = new JList<>(playersModel);
        StyleKit.styleList(playerList);
        JScrollPane playerScroll = new JScrollPane(playerList);
        StyleKit.styleScroll(playerScroll);

        CardPanel playersCard = new CardPanel("Jugadores registrados");
        playersCard.setContent(playerScroll);

        logArea.setEditable(false);
        StyleKit.styleTextArea(logArea);
        JScrollPane logScroll = new JScrollPane(logArea);
        StyleKit.styleScroll(logScroll);

        CardPanel logCard = new CardPanel("Balotas cantadas");
        logCard.setContent(logScroll);

        center.add(playersCard);
        center.add(logCard);
        return center;
    }

    private JPanel buildFooter() {
        JPanel footer = new JPanel(new GridLayout(1, 3, 16, 0));
        footer.setOpaque(false);
        footer.setBorder(BorderFactory.createEmptyBorder(16, 24, 24, 24));

        for (RoundButton b : new RoundButton[]{startButton, drawButton, endButton}) {
            b.setPreferredSize(new java.awt.Dimension(0, 46));
        }

        startButton.addActionListener(e -> runSafely(() -> {
            service.startGame();
            updateBrokerStatus(GameCodeStatus.IN_GAME);
        }));
        drawButton.addActionListener(e -> runSafely(service::drawNextBallot));
        endButton.addActionListener(e -> {
            int confirm = JOptionPane.showConfirmDialog(this,
                    "¿Finalizar la partida actual? Se repartirán cartones nuevos para la siguiente ronda.",
                    "Confirmar",
                    JOptionPane.YES_NO_OPTION);
            if (confirm == JOptionPane.YES_OPTION) {
                runSafely(() -> {
                    service.endGame();
                    // Vuelve a HOSTED: la sala sigue abierta para la próxima ronda.
                    updateBrokerStatus(GameCodeStatus.HOSTED);
                    lastLoggedBallots = 0;
                    SwingUtilities.invokeLater(() -> logArea.setText(""));
                });
            }
        });

        footer.add(startButton);
        footer.add(drawButton);
        footer.add(endButton);
        return footer;
    }

    /** Ejecuta una llamada RMI en un hilo aparte (puede tardar por la red). */
    private void runSafely(RmiAction action) {
        new Thread(() -> {
            try {
                action.run();
            } catch (Exception ex) {
                SwingUtilities.invokeLater(() ->
                        JOptionPane.showMessageDialog(this, "Error: " + ex.getMessage(), "Error", JOptionPane.ERROR_MESSAGE));
            }
        }, "GameServerUI-action").start();
    }

    /** Best-effort: si no hay Broker (modo legado) no hace nada. */
    private void updateBrokerStatus(GameCodeStatus status) {
        if (broker == null || code == null) {
            return;
        }
        try {
            broker.updateStatus(code, status);
        } catch (Exception ex) {
            System.err.println("No se pudo avisar al Broker el cambio a " + status + ": " + ex.getMessage());
        }
    }

    /**
     * Al cerrar la ventana del anfitrión, libera el código en el Broker
     * (para que quede disponible de nuevo) antes de terminar el proceso.
     */
    private void setupCloseBehavior() {
        if (broker == null) {
            return;
        }
        addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosing(WindowEvent e) {
                polling = false;
                try {
                    broker.releaseGame(code);
                } catch (Exception ex) {
                    System.err.println("No se pudo liberar el código " + code + ": " + ex.getMessage());
                }
                dispose();
                System.exit(0);
            }
        });
    }

    /**
     * Refresca el panel consultando por RMI cada {@link #POLL_MS} ms.
     * Reemplaza el viejo Runnable local: como Game puede vivir en otra
     * máquina (la del Broker), no hay forma de que nos "empuje" cambios
     * sin exponer esta ventana también a la red — así que preguntamos
     * nosotros, periódicamente, en un hilo aparte del EDT.
     */
    private void startPolling() {
        Thread poller = new Thread(() -> {
            while (polling) {
                try {
                    List<String> players = control.getPlayerNames();
                    boolean started = control.isGameStarted();
                    int calledCount = control.getCalledCount();
                    List<String> ballots = control.getCalledBallotsDisplay();

                    SwingUtilities.invokeLater(() -> applyState(players, started, calledCount, ballots));
                } catch (Exception ex) {
                    SwingUtilities.invokeLater(() ->
                            statusLabel.setText("Problemas de conexión, reintentando... (" + ex.getMessage() + ")"));
                }
                try {
                    Thread.sleep(POLL_MS);
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                }
            }
        }, "GameServerUI-poller");
        poller.setDaemon(true);
        poller.start();
    }

    private void applyState(List<String> players, boolean started, int calledCount, List<String> ballots) {
        playersModel.clear();
        for (String name : players) {
            playersModel.addElement(name);
        }

        startButton.setEnabled(!started);
        drawButton.setEnabled(started);

        statusLabel.setText(started
                ? "Juego en curso — balotas cantadas: " + calledCount + "/75"
                : "Esperando inicio — " + playersModel.size() + " jugador(es) registrado(s)");

        // Solo agrega al log las balotas nuevas desde el último poll.
        for (int i = lastLoggedBallots; i < ballots.size(); i++) {
            logArea.append(ballots.get(i) + "\n");
        }
        if (ballots.size() != lastLoggedBallots) {
            logArea.setCaretPosition(logArea.getDocument().getLength());
        }
        lastLoggedBallots = ballots.size();
    }

    @FunctionalInterface
    private interface RmiAction {
        void run() throws Exception;
    }

    /** Modo legado: una sola partida local, sin Broker (útil para pruebas rápidas en una sola máquina). */
    public static void main(String[] args) {
        try {
            java.rmi.registry.Registry registry = java.rmi.registry.LocateRegistry.createRegistry(Game.RMI_PORT);
            Game bingoServer = new Game();
            registry.rebind("BingoService", bingoServer);
            System.out.println("Servidor de Bingo listo y esperando clientes...");
            SwingUtilities.invokeLater(() -> new GameServerUI(bingoServer).setVisible(true));
        } catch (Exception e) {
            System.err.println("Excepción en el servidor: " + e.getMessage());
            e.printStackTrace();
            JOptionPane.showMessageDialog(null, "No se pudo iniciar el servidor: " + e.getMessage());
        }
    }
}
