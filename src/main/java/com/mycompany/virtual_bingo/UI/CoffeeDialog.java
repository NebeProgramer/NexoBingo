/*
 * Ventana "invítame un café", con el mismo comportamiento que la del
 * proyecto Problema-Programación-Lineal: aparece al abrir la app, y si
 * el usuario elige "Tal vez más tarde" no vuelve a aparecer durante 15
 * días (se guarda con java.util.prefs.Preferences, que persiste entre
 * ejecuciones sin necesitar un archivo propio).
 */
package com.mycompany.virtual_bingo.UI;

import java.awt.BorderLayout;
import java.awt.Desktop;
import java.awt.Dimension;
import java.awt.GridLayout;
import java.net.URI;
import java.util.prefs.Preferences;

import javax.swing.BorderFactory;
import javax.swing.JDialog;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.SwingConstants;
import javax.swing.SwingUtilities;

public class CoffeeDialog extends JDialog {

    // TODO Anderson: reemplaza esto con tu enlace real (el mismo que usas
    // en el proyecto PPL — Ko-fi, Buy Me a Coffee, PayPal.me, etc).
    private static final String COFFEE_URL = "https://www.buymeacoffee.com/tu-usuario";

    private static final String PREF_KEY = "coffee_dialog_dismissed_until";
    private static final long DISMISS_MILLIS = 15L * 24 * 60 * 60 * 1000; // 15 días

    private CoffeeDialog(JFrame owner) {
        super(owner, "Invítame un café", true);
        com.mycompany.virtual_bingo.UI.Theme.applyAppIcon(this);
        buildUI();
    }

    /**
     * Muestra el cartel solo si no fue pospuesto hace menos de 15 días.
     * Llamar una vez, al arrancar la app (ver Virtual_Bingo.main()).
     */
    public static void maybeShow(JFrame owner) {
        Preferences prefs = Preferences.userNodeForPackage(CoffeeDialog.class);
        long dismissedUntil = prefs.getLong(PREF_KEY, 0L);
        if (System.currentTimeMillis() < dismissedUntil) {
            return;
        }
        SwingUtilities.invokeLater(() -> new CoffeeDialog(owner).setVisible(true));
    }

    private void buildUI() {
        setDefaultCloseOperation(JDialog.DISPOSE_ON_CLOSE);
        setSize(500, 420);
        setResizable(false);
        setLocationRelativeTo(getOwner());
        getContentPane().setBackground(Theme.BG_DARK);
        setLayout(new BorderLayout(0, 0));

        JPanel content = new JPanel(new BorderLayout(0, 14));
        content.setOpaque(false);
        content.setBorder(BorderFactory.createEmptyBorder(26, 28, 20, 28));

        JLabel cup = new JLabel("☕", SwingConstants.CENTER);
        cup.setFont(cup.getFont().deriveFont(48f));
        cup.setAlignmentX(java.awt.Component.CENTER_ALIGNMENT);

        JLabel title = new JLabel("¿Te gustó NexoBingo?", SwingConstants.CENTER);
        title.setFont(Theme.SUBTITLE_FONT.deriveFont(java.awt.Font.BOLD, 18f));
        title.setForeground(Theme.GOLD);
        title.setAlignmentX(java.awt.Component.CENTER_ALIGNMENT);

        JLabel body = new JLabel(
                "<html><div style='text-align:center; width:400px;'>"
                + "Si te divirtió el proyecto, considera invitarme a un café "
                + "para ayudar a mejorar este tipo de herramientas."
                + "</div></html>", SwingConstants.CENTER);
        body.setFont(Theme.SUBTITLE_FONT);
        body.setForeground(Theme.TEXT_MUTED);
        body.setAlignmentX(java.awt.Component.CENTER_ALIGNMENT);

        JPanel textBlock = new JPanel();
        textBlock.setOpaque(false);
        textBlock.setLayout(new javax.swing.BoxLayout(textBlock, javax.swing.BoxLayout.Y_AXIS));
        textBlock.add(cup);
        textBlock.add(javax.swing.Box.createVerticalStrut(10));
        textBlock.add(title);
        textBlock.add(javax.swing.Box.createVerticalStrut(10));
        textBlock.add(body);

        RoundButton coffeeButton = new RoundButton("Invitarme un café", Theme.GOLD_DARK);
        RoundButton laterButton = new RoundButton("Tal vez más tarde", Theme.BLUE);
        for (RoundButton b : new RoundButton[]{coffeeButton, laterButton}) {
            b.setPreferredSize(new Dimension(0, 42));
        }
        coffeeButton.addActionListener(e -> onCoffee());
        laterButton.addActionListener(e -> onLater());

        JPanel buttons = new JPanel(new GridLayout(2, 1, 0, 10));
        buttons.setOpaque(false);
        buttons.add(coffeeButton);
        buttons.add(laterButton);

        content.add(textBlock, BorderLayout.CENTER);
        content.add(buttons, BorderLayout.SOUTH);
        add(content, BorderLayout.CENTER);
    }

    private void onCoffee() {
        try {
            Desktop.getDesktop().browse(new URI(COFFEE_URL));
        } catch (Exception ex) {
            JOptionPane.showMessageDialog(this, "Abre este enlace en tu navegador:\n" + COFFEE_URL);
        }
        postpone();
        dispose();
    }

    private void onLater() {
        postpone();
        dispose();
    }

    private void postpone() {
        Preferences prefs = Preferences.userNodeForPackage(CoffeeDialog.class);
        prefs.putLong(PREF_KEY, System.currentTimeMillis() + DISMISS_MILLIS);
    }
}
