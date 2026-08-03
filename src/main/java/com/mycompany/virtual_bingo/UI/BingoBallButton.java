/*
 * Botón circular estilo balota de bingo, usado para cada casilla del
 * cartón del cliente. Reemplaza los JButton cuadrados por defecto.
 */
package com.mycompany.virtual_bingo.UI;

import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Cursor;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.RenderingHints;

import javax.swing.JButton;
import javax.swing.SwingConstants;

public class BingoBallButton extends JButton {

    private Color ringColor = Theme.GOLD;
    private boolean marked = false;
    private boolean lockedCell = false;

    public BingoBallButton() {
        setContentAreaFilled(false);
        setFocusPainted(false);
        setBorderPainted(false);
        setOpaque(false);
        setFont(Theme.BALL_FONT);
        setForeground(Theme.TEXT_LIGHT);
        setHorizontalAlignment(SwingConstants.CENTER);
        setCursor(Cursor.getPredefinedCursor(Cursor.HAND_CURSOR));
    }

    public void setRingColor(Color color) {
        this.ringColor = color;
        repaint();
    }

    public void setMarked(boolean marked) {
        this.marked = marked;
        repaint();
    }

    /** Casilla especial (ID) que no se puede marcar. */
    public void setLockedCell(boolean locked) {
        this.lockedCell = locked;
        setEnabled(!locked);
        repaint();
    }

    /**
     * Restaura el botón a su estado inicial, listo para una nueva partida.
     */
    public void reset() {
        setText("");
        setMarked(false);
        setLockedCell(false);
        setEnabled(false);
        setCursor(Cursor.getPredefinedCursor(Cursor.DEFAULT_CURSOR));
        repaint();
    }

    @Override
    protected void paintComponent(Graphics g) {
        Graphics2D g2 = (Graphics2D) g.create();
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);

        int d = Math.min(getWidth(), getHeight()) - 6;
        int x = (getWidth() - d) / 2;
        int y = (getHeight() - d) / 2;

        Color fill;
        if (lockedCell) {
            fill = Theme.BG_CARD;
        } else if (marked) {
            fill = getModel().isRollover() ? Theme.GREEN.brighter() : Theme.GREEN;
        } else {
            fill = getModel().isRollover() ? Theme.BG_CARD.brighter() : Theme.BG_CARD;
        }

        g2.setColor(fill);
        g2.fillOval(x, y, d, d);

        g2.setStroke(new BasicStroke(2.4f));
        g2.setColor(lockedCell ? Theme.TEXT_MUTED : ringColor);
        g2.drawOval(x, y, d, d);

        g2.dispose();
        super.paintComponent(g);
    }
}
