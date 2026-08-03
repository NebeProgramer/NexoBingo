/*
 * Interfaz gráfica del cliente. El jugador marca su propia casilla (no se
 * marca sola al cantarse la balota) y decide cuándo cantar BINGO.
 *
 * CAMBIO DE DISEÑO: este cliente ya NO se registra como objeto remoto
 * (antes se exportaba a sí mismo con UnicastRemoteObject para que el
 * servidor le "empujara" eventos). Eso requería que el servidor pudiera
 * conectarse DE VUELTA al cliente — imposible detrás de un router
 * doméstico normal. Ahora el cliente solo hace llamadas SALIENTES:
 * registerPlayer una vez, y pollState() en un bucle. Nunca necesita ser
 * alcanzable desde afuera.
 *
 * También, como ahora siempre se entra por la ventana Nexo (que ya
 * resolvió el BingoService a través del Broker), ya no existe el
 * formulario manual de "nombre + servidor + Conectar" — se registra solo
 * apenas se construye.
 */
package com.mycompany.virtual_bingo.Client;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.GridLayout;
import java.rmi.RemoteException;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import javax.swing.BorderFactory;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.SwingConstants;
import javax.swing.SwingUtilities;
import javax.swing.SwingWorker;

import com.mycompany.virtual_bingo.Game_Objects.Ballots;
import com.mycompany.virtual_bingo.Game_Objects.Client_Game_Objects.Tables;
import com.mycompany.virtual_bingo.RMI.BingoService;
import com.mycompany.virtual_bingo.RMI.ClientState;
import com.mycompany.virtual_bingo.RMI.RegistrationResult;
import com.mycompany.virtual_bingo.UI.BingoBallButton;
import com.mycompany.virtual_bingo.UI.CardPanel;
import com.mycompany.virtual_bingo.UI.RoundButton;
import com.mycompany.virtual_bingo.UI.StyleKit;
import com.mycompany.virtual_bingo.UI.Theme;

/**
 * Cliente de Bingo con interfaz gráfica y juego manual.
 *
 * @author andor
 */
public class BingoClientUI extends JFrame {

    private static final String[] LETTERS = {"B", "I", "N", "G", "O"};
    private static final int POLL_MS = 800;

    // Table[col][row]: col = índice de letra (B,I,N,G,O), row = fila 0..4
    private final BingoBallButton[][] cells = new BingoBallButton[5][5];
    private final Set<Integer> calledNumbers = ConcurrentHashMap.newKeySet();

    private final RoundButton bingoButton = new RoundButton("★  ¡CANTAR BINGO!  ★", Theme.GOLD_DARK);
    private final JTextArea logArea = new JTextArea();
    private final JLabel statusLabel = new JLabel("Conectando...");

    private final String playerName;
    private final String code;
    private final BingoService service;
    private volatile int tableId = -1;
    private volatile Tables myTable;
    private volatile boolean polling = true;

    private int lastSeenRoundId = -1;
    private int lastSeenBallotCount = 0;
    private int lastSeenWinnerRoundId = -1;

    /**
     * Único punto de entrada: usado por
     * {@link com.mycompany.virtual_bingo.Nexus.NexusUI} tras resolver el
     * {@link BingoService} de la sala a través del Broker.
     */
    public BingoClientUI(String playerName, String code, BingoService service) {
        super("NexoBingo — Cliente" + (code != null ? " · Código " + code : ""));
        this.playerName = playerName;
        this.code = code;
        this.service = service;

        com.mycompany.virtual_bingo.UI.Theme.applyAppIcon(this);

        buildUI();
        register();
    }

    private void buildUI() {
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setSize(760, 700);
        setLocationRelativeTo(null);
        getContentPane().setBackground(Theme.BG_DARK);
        setLayout(new BorderLayout(0, 0));

        addWindowListener(new java.awt.event.WindowAdapter() {
            @Override
            public void windowClosing(java.awt.event.WindowEvent e) {
                polling = false;
            }
        });

        add(buildHeader(), BorderLayout.NORTH);
        add(buildCenter(), BorderLayout.CENTER);
        add(buildFooter(), BorderLayout.SOUTH);
    }

    private JPanel buildHeader() {
        JPanel header = new JPanel(new BorderLayout(0, 4));
        header.setOpaque(true);
        header.setBackground(Theme.BG_DARK);
        header.setBorder(BorderFactory.createEmptyBorder(18, 24, 10, 24));
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
        JPanel center = new JPanel(new BorderLayout(16, 0));
        center.setOpaque(false);
        center.setBorder(BorderFactory.createEmptyBorder(4, 24, 0, 24));

        center.add(buildCardPanel(), BorderLayout.CENTER);
        center.add(buildLogPanel(), BorderLayout.EAST);
        return center;
    }

    private CardPanel buildCardPanel() {
        JPanel grid = new JPanel(new GridLayout(6, 5, 6, 6));
        grid.setOpaque(false);

        for (String letter : LETTERS) {
            JLabel headerLabel = new JLabel(letter, SwingConstants.CENTER);
            headerLabel.setFont(Theme.LETTER_FONT);
            headerLabel.setForeground(Theme.letterColor(letter));
            grid.add(headerLabel);
        }

        for (int row = 0; row < 5; row++) {
            for (int col = 0; col < 5; col++) {
                BingoBallButton cell = new BingoBallButton();
                cell.setRingColor(Theme.letterColor(LETTERS[col]));
                cell.setEnabled(false);
                final int c = col, r = row;
                cell.addActionListener(e -> onCellClicked(c, r));
                cells[col][row] = cell;
                grid.add(cell);
            }
        }

        CardPanel card = new CardPanel("Tu cartón");
        card.setContent(grid);
        return card;
    }

    private CardPanel buildLogPanel() {
        logArea.setEditable(false);
        StyleKit.styleTextArea(logArea);
        JScrollPane logScroll = new JScrollPane(logArea);
        StyleKit.styleScroll(logScroll);

        CardPanel card = new CardPanel("Balotas cantadas");
        card.setPreferredSize(new Dimension(190, 0));
        card.setContent(logScroll);
        return card;
    }

    private JPanel buildFooter() {
        JPanel footer = new JPanel(new BorderLayout());
        footer.setOpaque(false);
        footer.setBorder(BorderFactory.createEmptyBorder(16, 24, 24, 24));

        bingoButton.setEnabled(false);
        bingoButton.setPreferredSize(new Dimension(0, 52));
        bingoButton.addActionListener(e -> claimBingo());

        footer.add(bingoButton, BorderLayout.CENTER);
        return footer;
    }

    private void register() {
        statusLabel.setText("Registrando a " + playerName + "...");
        new SwingWorker<RegistrationResult, Void>() {
            @Override
            protected RegistrationResult doInBackground() throws Exception {
                return service.registerPlayer(playerName);
            }

            @Override
            protected void done() {
                try {
                    RegistrationResult result = get();
                    if (!result.isAccepted()) {
                        statusLabel.setText(result.getMessage());
                        JOptionPane.showMessageDialog(BingoClientUI.this, result.getMessage());
                        return;
                    }
                    tableId = result.getTableId();
                    statusLabel.setText(result.getMessage());
                    startPolling();
                } catch (Exception ex) {
                    statusLabel.setText("No se pudo conectar: " + ex.getMessage());
                    JOptionPane.showMessageDialog(BingoClientUI.this, "No se pudo conectar: " + ex.getMessage());
                }
            }
        }.execute();
    }

    /**
     * Marcado MANUAL: el jugador hace clic en su casilla; solo se marca si
     * esa balota ya fue cantada por el servidor. Un segundo clic la
     * desmarca (por si el jugador se equivoca).
     */
    private void onCellClicked(int col, int row) {
        if (myTable == null) {
            return;
        }
        Ballots ballot = myTable.getTable()[col][row];
        if ("ID".equals(ballot.getLetter())) {
            return; // la casilla central de ID no se marca
        }
        if (ballot.getStatus() == Ballots.Status.Unused && !calledNumbers.contains(ballot.getNumber())) {
            JOptionPane.showMessageDialog(this, "Esa balota todavía no ha sido cantada.");
            return;
        }

        if (ballot.getStatus() == Ballots.Status.Unused) {
            myTable.usedBallot(col, row);
        } else {
            myTable.unusedBallot(col, row);
        }
        refreshCard();
    }

    private void claimBingo() {
        if (myTable == null) {
            return;
        }
        bingoButton.setEnabled(false);
        new SwingWorker<String, Void>() {
            @Override
            protected String doInBackground() throws Exception {
                return service.singBingo(tableId);
            }

            @Override
            protected void done() {
                try {
                    String message = get();
                    statusLabel.setText(message);
                    JOptionPane.showMessageDialog(BingoClientUI.this, message);
                } catch (Exception ex) {
                    JOptionPane.showMessageDialog(BingoClientUI.this, "Error al cantar BINGO: " + ex.getMessage());
                    bingoButton.setEnabled(true);
                }
            }
        }.execute();
    }

    private void refreshCard() {
        Tables table = myTable;
        if (table == null) {
            return;
        }
        for (int col = 0; col < 5; col++) {
            for (int row = 0; row < 5; row++) {
                Ballots b = table.getTable()[col][row];
                BingoBallButton btn = cells[col][row];
                if ("ID".equals(b.getLetter())) {
                    btn.setText("#" + b.getNumber());
                    btn.setLockedCell(true);
                } else {
                    btn.setText(String.valueOf(b.getNumber()));
                    btn.setEnabled(true);
                    btn.setMarked(b.getStatus() == Ballots.Status.Used);
                }
            }
        }
    }

    private void resetForNewRound() {
        myTable = null;
        calledNumbers.clear();
        lastSeenBallotCount = 0;
        logArea.setText("");
        bingoButton.setEnabled(false);
        for (int col = 0; col < 5; col++) {
            for (int row = 0; row < 5; row++) {
                cells[col][row].reset();
            }
        }
    }

    /**
     * Bucle de polling: reemplaza a los callbacks push. Corre en un hilo
     * aparte del EDT (las llamadas RMI pueden tardar por la red) y solo
     * toca Swing a través de invokeLater.
     */
    private void startPolling() {
        Thread poller = new Thread(() -> {
            while (polling) {
                try {
                    ClientState state = service.pollState(tableId);
                    SwingUtilities.invokeLater(() -> applyState(state));
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
        }, "BingoClientUI-poller");
        poller.setDaemon(true);
        poller.start();
    }

    private void applyState(ClientState state) {
        // Ronda nueva (cierre manual o por BINGO): limpiar todo y esperar.
        if (state.getRoundId() != lastSeenRoundId) {
            lastSeenRoundId = state.getRoundId();
            resetForNewRound();
            if (!state.isGameStarted()) {
                statusLabel.setText("Ronda lista. Esperando que el anfitrión inicie el juego...");
            }
        }

        // El juego inició y todavía no tenemos el cartón: tomarlo.
        if (state.isGameStarted() && myTable == null && state.getTable() != null) {
            myTable = state.getTable();
            statusLabel.setText("¡Juego iniciado! Tu cartón es el #" + myTable.getTable_id());
            bingoButton.setEnabled(true);
            refreshCard();
        }

        // Agregar al log solo las balotas nuevas desde el último poll.
        List<String> ballots = state.getCalledBallotsDisplay();
        for (int i = lastSeenBallotCount; i < ballots.size(); i++) {
            String display = ballots.get(i); // formato "B-12"
            logArea.append(display + "\n");
            String[] parts = display.split("-");
            if (parts.length == 2) {
                try {
                    calledNumbers.add(Integer.parseInt(parts[1]));
                } catch (NumberFormatException ignored) {
                    // no debería pasar, pero no vale la pena tumbar el polling por esto
                }
            }
        }
        if (ballots.size() != lastSeenBallotCount) {
            logArea.setCaretPosition(logArea.getDocument().getLength());
        }
        lastSeenBallotCount = ballots.size();

        // Anuncio de victoria (propia o ajena), una sola vez por ronda.
        if (state.getWinnerTableId() != -1 && state.getWinnerRoundId() != lastSeenWinnerRoundId) {
            lastSeenWinnerRoundId = state.getWinnerRoundId();
            boolean iWon = state.getWinnerTableId() == tableId;
            String msg = iWon ? "¡Ganaste! Cartón #" + state.getWinnerTableId()
                    : "Ganó el cartón #" + state.getWinnerTableId();
            statusLabel.setText(msg);
            bingoButton.setEnabled(false);
            JOptionPane.showMessageDialog(this, msg);
        }
    }
}
