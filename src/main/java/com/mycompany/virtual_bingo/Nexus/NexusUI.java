/*
 * Ventana "nexo": el punto de entrada real del juego. Antes de ver el
 * panel de anfitrión o el cartón de jugador, el usuario pasa por aquí y
 * decide si CREA una partida (pide un código de 6 dígitos y abre una
 * sala) o se UNE a una ya existente (escribe el código que le pasaron).
 *
 * Toda la lógica de colisión de códigos vive en el Broker
 * (com.mycompany.virtual_bingo.Broker.BrokerServer), que debe estar
 * corriendo antes de abrir esta ventana.
 */
package com.mycompany.virtual_bingo.Nexus;

import com.mycompany.virtual_bingo.Broker.BingoBroker;
import com.mycompany.virtual_bingo.Broker.GameNotAvailableException;
import com.mycompany.virtual_bingo.Broker.HostedGame;
import com.mycompany.virtual_bingo.Client.BingoClientUI;
import com.mycompany.virtual_bingo.RMI.BingoService;
import com.mycompany.virtual_bingo.Server.BingoHostControl;
import com.mycompany.virtual_bingo.Server.GameServerUI;
import com.mycompany.virtual_bingo.UI.CardPanel;
import com.mycompany.virtual_bingo.UI.RoundButton;
import com.mycompany.virtual_bingo.UI.StyleKit;
import com.mycompany.virtual_bingo.UI.Theme;

import java.awt.BorderLayout;
import java.awt.CardLayout;
import java.awt.Dimension;
import java.awt.GridLayout;
import java.rmi.registry.LocateRegistry;
import java.rmi.registry.Registry;

import javax.swing.BorderFactory;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JTextField;
import javax.swing.SwingConstants;
import javax.swing.SwingUtilities;
import javax.swing.SwingWorker;

public class NexusUI extends JFrame {

    /**
     * Flag SOLO para desarrolladores: cámbialo a "true" y recompila en
     * NetBeans si necesitas apuntar a un broker distinto (por ejemplo,
     * uno local mientras pruebas cambios). En producción debe quedar en
     * "false" — el campo de IP no aparece y siempre se usa
     * PRODUCTION_BROKER_HOST, así los jugadores no tienen forma de
     * (ni necesidad de) tocarlo.
     */
    private static final boolean DEV_MODE = false;
    private static final String PRODUCTION_BROKER_HOST = "157.137.227.165";

    private static final String CARD_HOME = "home";
    private static final String CARD_CREATE = "create";
    private static final String CARD_JOIN = "join";

    private final JTextField brokerHostField = new JTextField(PRODUCTION_BROKER_HOST);

    private final CardLayout cardLayout = new CardLayout();
    private final JPanel cards = new JPanel(cardLayout);

    // --- Panel "Crear partida" ---
    private final JLabel createStatusLabel = new JLabel(" ");
    private final RoundButton createGameButton = new RoundButton("Crear sala", Theme.GOLD_DARK);

    // --- Panel "Unirse a partida" ---
    private final JTextField nameField = new JTextField("Jugador");
    private final JTextField codeField = new JTextField();
    private final JLabel joinStatusLabel = new JLabel(" ");
    private final RoundButton joinButton = new RoundButton("Unirse", Theme.GREEN);

    public NexusUI() {
        super("NexoBingo — Nexo");
        com.mycompany.virtual_bingo.UI.Theme.applyAppIcon(this);
        buildUI();
    }

    private void buildUI() {
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setSize(560, 480);
        setLocationRelativeTo(null);
        getContentPane().setBackground(Theme.BG_DARK);
        setLayout(new BorderLayout());

        cards.setOpaque(false);
        cards.add(buildHomeCard(), CARD_HOME);
        cards.add(buildCreateCard(), CARD_CREATE);
        cards.add(buildJoinCard(), CARD_JOIN);

        add(cards, BorderLayout.CENTER);
    }

    private JPanel buildHomeCard() {
        JPanel panel = new JPanel(new BorderLayout(0, 18));
        panel.setOpaque(false);
        panel.setBorder(BorderFactory.createEmptyBorder(30, 30, 30, 30));

        JLabel title = new JLabel("NexoBingo", SwingConstants.CENTER);
        title.setFont(Theme.TITLE_FONT);
        title.setForeground(Theme.GOLD);

        JLabel subtitle = new JLabel("¿Qué quieres hacer?", SwingConstants.CENTER);
        subtitle.setFont(Theme.SUBTITLE_FONT);
        subtitle.setForeground(Theme.TEXT_MUTED);

        JPanel titleBlock = new JPanel(new GridLayout(2, 1, 0, 6));
        titleBlock.setOpaque(false);
        titleBlock.add(title);
        titleBlock.add(subtitle);

        JPanel brokerRow = new JPanel(new java.awt.FlowLayout(java.awt.FlowLayout.CENTER, 8, 0));
        brokerRow.setOpaque(false);
        if (DEV_MODE) {
            JLabel brokerLabel = new JLabel("Servidor central (broker):");
            brokerLabel.setForeground(Theme.TEXT_MUTED);
            brokerLabel.setFont(Theme.SUBTITLE_FONT);
            brokerHostField.setPreferredSize(new Dimension(160, 30));
            StyleKit.styleTextField(brokerHostField);
            brokerRow.add(brokerLabel);
            brokerRow.add(brokerHostField);
        }

        RoundButton createButton = new RoundButton("Crear partida", Theme.GOLD_DARK);
        RoundButton joinButtonHome = new RoundButton("Unirse a partida", Theme.BLUE);
        for (RoundButton b : new RoundButton[]{createButton, joinButtonHome}) {
            b.setPreferredSize(new Dimension(0, 50));
        }
        createButton.addActionListener(e -> {
            resetCreateCard();
            cardLayout.show(cards, CARD_CREATE);
        });
        joinButtonHome.addActionListener(e -> {
            resetJoinCard();
            cardLayout.show(cards, CARD_JOIN);
        });

        JPanel buttons = new JPanel(new GridLayout(2, 1, 0, 14));
        buttons.setOpaque(false);
        buttons.setBorder(BorderFactory.createEmptyBorder(10, 40, 10, 40));
        buttons.add(createButton);
        buttons.add(joinButtonHome);

        JPanel top = new JPanel(new BorderLayout(0, 24));
        top.setOpaque(false);
        top.add(titleBlock, BorderLayout.NORTH);
        top.add(brokerRow, BorderLayout.SOUTH);

        panel.add(top, BorderLayout.NORTH);
        panel.add(buttons, BorderLayout.CENTER);
        return panel;
    }

    private JPanel buildCreateCard() {
        JPanel wrapper = new JPanel(new BorderLayout());
        wrapper.setOpaque(false);
        wrapper.setBorder(BorderFactory.createEmptyBorder(30, 30, 30, 30));

        CardPanel card = new CardPanel("Crear partida");

        JPanel content = new JPanel(new GridLayout(3, 1, 0, 16));
        content.setOpaque(false);

        createStatusLabel.setHorizontalAlignment(SwingConstants.CENTER);
        createStatusLabel.setForeground(Theme.TEXT_MUTED);
        createStatusLabel.setFont(Theme.SUBTITLE_FONT);

        createGameButton.setPreferredSize(new Dimension(0, 46));
        createGameButton.addActionListener(e -> createGame());

        RoundButton back = new RoundButton("← Volver", Theme.RED);
        back.addActionListener(e -> cardLayout.show(cards, CARD_HOME));

        content.add(createStatusLabel);
        content.add(createGameButton);
        content.add(back);

        card.setContent(content);
        wrapper.add(card, BorderLayout.CENTER);
        return wrapper;
    }

    private JPanel buildJoinCard() {
        JPanel wrapper = new JPanel(new BorderLayout());
        wrapper.setOpaque(false);
        wrapper.setBorder(BorderFactory.createEmptyBorder(30, 30, 30, 30));

        CardPanel card = new CardPanel("Unirse a partida");

        JPanel content = new JPanel(new GridLayout(6, 1, 0, 12));
        content.setOpaque(false);

        JLabel nameLabel = new JLabel("Tu nombre:");
        JLabel codeLabelText = new JLabel("Código de 6 dígitos:");
        for (JLabel l : new JLabel[]{nameLabel, codeLabelText}) {
            l.setForeground(Theme.TEXT_MUTED);
            l.setFont(Theme.SUBTITLE_FONT);
        }
        StyleKit.styleTextField(nameField);
        StyleKit.styleTextField(codeField);

        joinStatusLabel.setHorizontalAlignment(SwingConstants.CENTER);
        joinStatusLabel.setForeground(Theme.TEXT_MUTED);
        joinStatusLabel.setFont(Theme.SUBTITLE_FONT);

        joinButton.addActionListener(e -> joinGame());

        RoundButton back = new RoundButton("← Volver", Theme.RED);
        back.addActionListener(e -> cardLayout.show(cards, CARD_HOME));

        content.add(nameLabel);
        content.add(nameField);
        content.add(codeLabelText);
        content.add(codeField);
        content.add(joinButton);
        content.add(joinStatusLabel);

        card.setContent(content);
        wrapper.add(card, BorderLayout.CENTER);

        JPanel south = new JPanel(new BorderLayout());
        south.setOpaque(false);
        south.add(back, BorderLayout.SOUTH);
        wrapper.add(south, BorderLayout.SOUTH);
        return wrapper;
    }

    // ==================================================================
    //  Flujo "Crear partida"
    // ==================================================================

    private void resetCreateCard() {
        createStatusLabel.setText(" ");
        createGameButton.setEnabled(true);
    }

    private void createGame() {
        createGameButton.setEnabled(false);
        createStatusLabel.setText("Creando sala...");

        new SwingWorker<HostedGame, Void>() {
            @Override
            protected HostedGame doInBackground() throws Exception {
                BingoBroker broker = resolveBroker();
                HostedGame hosted = broker.createGame();
                return hosted;
            }

            @Override
            protected void done() {
                try {
                    HostedGame hosted = get();
                    BingoBroker broker = resolveBroker();
                    BingoService svc = hosted.getService();
                    SwingUtilities.invokeLater(() -> {
                        new GameServerUI((BingoService & BingoHostControl) svc, hosted.getCode(), broker).setVisible(true);
                        dispose();
                    });
                } catch (Exception ex) {
                    createStatusLabel.setText("No se pudo crear la sala: " + rootMessage(ex));
                    createGameButton.setEnabled(true);
                }
            }
        }.execute();
    }

    // ==================================================================
    //  Flujo "Unirse a partida"
    // ==================================================================

    private void resetJoinCard() {
        joinStatusLabel.setText(" ");
        codeField.setText("");
        joinButton.setEnabled(true);
    }

    private void joinGame() {
        String playerName = nameField.getText().trim();
        String code = codeField.getText().trim();

        if (playerName.isEmpty()) {
            JOptionPane.showMessageDialog(this, "Escribe tu nombre.");
            return;
        }
        if (!code.matches("\\d{6}")) {
            JOptionPane.showMessageDialog(this, "El código debe tener exactamente 6 dígitos.");
            return;
        }

        joinButton.setEnabled(false);
        joinStatusLabel.setText("Buscando la sala " + code + "...");

        new SwingWorker<BingoService, Void>() {
            @Override
            protected BingoService doInBackground() throws Exception {
                BingoBroker broker = resolveBroker();
                return broker.joinGame(code);
            }

            @Override
            protected void done() {
                try {
                    BingoService service = get();
                    SwingUtilities.invokeLater(() -> {
                        new BingoClientUI(playerName, code, service).setVisible(true);
                        dispose();
                    });
                } catch (Exception ex) {
                    joinButton.setEnabled(true);
                    if (rootCause(ex) instanceof GameNotAvailableException gnae) {
                        joinStatusLabel.setText(gnae.getMessage());
                    } else {
                        joinStatusLabel.setText("No se pudo conectar: " + rootMessage(ex));
                    }
                }
            }
        }.execute();
    }

    // ==================================================================
    //  Utilidades
    // ==================================================================

    private BingoBroker resolveBroker() throws Exception {
        String host = brokerHostField.getText().trim();
        Registry registry = LocateRegistry.getRegistry(host.isEmpty() ? "localhost" : host, 1099);
        return (BingoBroker) registry.lookup("BingoBroker");
    }

    private static Throwable rootCause(Throwable t) {
        Throwable cause = t;
        while (cause.getCause() != null && cause.getCause() != cause) {
            cause = cause.getCause();
        }
        return cause;
    }

    private static String rootMessage(Throwable t) {
        Throwable cause = rootCause(t);
        return cause.getMessage() != null ? cause.getMessage() : cause.toString();
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> new NexusUI().setVisible(true));
    }
}
