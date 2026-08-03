/*
 * Contenedor con esquinas redondeadas y un título opcional en dorado,
 * para reemplazar los TitledBorder grises por defecto de Swing.
 */
package com.mycompany.virtual_bingo.UI;

import java.awt.BorderLayout;
import java.awt.Font;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.RenderingHints;

import javax.swing.BorderFactory;
import javax.swing.JLabel;
import javax.swing.JPanel;

public class CardPanel extends JPanel {

    private final int arc;

    public CardPanel(String title) {
        this(title, 18);
    }

    public CardPanel(String title, int arc) {
        super(new BorderLayout(0, 10));
        this.arc = arc;
        setOpaque(false);
        setBorder(BorderFactory.createEmptyBorder(14, 16, 14, 16));

        if (title != null) {
            JLabel label = new JLabel(title.toUpperCase());
            label.setFont(Theme.SECTION_FONT);
            label.setForeground(Theme.GOLD);
            add(label, BorderLayout.NORTH);
        }
    }

    public void setContent(java.awt.Component content) {
        add(content, BorderLayout.CENTER);
    }

    @Override
    protected void paintComponent(Graphics g) {
        Graphics2D g2 = (Graphics2D) g.create();
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g2.setColor(Theme.BG_PANEL);
        g2.fillRoundRect(0, 0, getWidth(), getHeight(), arc, arc);
        g2.dispose();
        super.paintComponent(g);
    }
}
