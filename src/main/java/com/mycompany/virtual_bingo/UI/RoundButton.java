/*
 * JButton con esquinas redondeadas, sin el relieve gris típico de Swing.
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

public class RoundButton extends JButton {

    private Color base;
    private final int arc;

    public RoundButton(String text, Color base) {
        this(text, base, 16);
    }

    public RoundButton(String text, Color base, int arc) {
        super(text);
        this.base = base;
        this.arc = arc;
        setContentAreaFilled(false);
        setFocusPainted(false);
        setBorderPainted(false);
        setOpaque(false);
        setForeground(Theme.TEXT_LIGHT);
        setFont(Theme.BUTTON_FONT);
        setHorizontalAlignment(SwingConstants.CENTER);
        setCursor(Cursor.getPredefinedCursor(Cursor.HAND_CURSOR));
    }

    public void setBaseColor(Color color) {
        this.base = color;
        repaint();
    }

    @Override
    protected void paintComponent(Graphics g) {
        Graphics2D g2 = (Graphics2D) g.create();
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);

        Color fill;
        if (!isEnabled()) {
            fill = new Color(base.getRed(), base.getGreen(), base.getBlue(), 70);
        } else if (getModel().isPressed()) {
            fill = base.darker();
        } else if (getModel().isRollover()) {
            fill = brighten(base, 24);
        } else {
            fill = base;
        }

        g2.setColor(fill);
        g2.fillRoundRect(0, 0, getWidth(), getHeight(), arc, arc);

        g2.setStroke(new BasicStroke(1.2f));
        g2.setColor(new Color(255, 255, 255, isEnabled() ? 40 : 15));
        g2.drawRoundRect(0, 0, getWidth() - 1, getHeight() - 1, arc, arc);

        g2.dispose();
        super.paintComponent(g);
    }

    private static Color brighten(Color c, int amount) {
        return new Color(
                Math.min(255, c.getRed() + amount),
                Math.min(255, c.getGreen() + amount),
                Math.min(255, c.getBlue() + amount));
    }
}
