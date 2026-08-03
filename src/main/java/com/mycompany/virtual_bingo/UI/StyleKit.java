/*
 * Métodos de conveniencia para "vestir" componentes Swing estándar
 * (JTextField, JList, JTextArea, JScrollPane) con el tema oscuro, sin
 * repetir el mismo bloque de estilos en cada ventana.
 */
package com.mycompany.virtual_bingo.UI;

import java.awt.Component;

import javax.swing.BorderFactory;
import javax.swing.DefaultListCellRenderer;
import javax.swing.JList;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.JTextField;
import javax.swing.border.Border;

public final class StyleKit {

    private StyleKit() {
    }

    public static void styleTextField(JTextField field) {
        field.setBackground(Theme.BG_CARD);
        field.setForeground(Theme.TEXT_LIGHT);
        field.setCaretColor(Theme.GOLD);
        field.setFont(Theme.SUBTITLE_FONT);
        Border line = BorderFactory.createLineBorder(Theme.BORDER, 1, true);
        field.setBorder(BorderFactory.createCompoundBorder(line, BorderFactory.createEmptyBorder(6, 10, 6, 10)));
    }

    public static void styleTextArea(JTextArea area) {
        area.setBackground(Theme.BG_CARD);
        area.setForeground(new java.awt.Color(0xA9E4B4));
        area.setFont(Theme.MONO_FONT);
        area.setCaretColor(Theme.GOLD);
        area.setBorder(BorderFactory.createEmptyBorder(8, 10, 8, 10));
    }

    public static void styleScroll(JScrollPane scroll) {
        scroll.setBorder(BorderFactory.createEmptyBorder());
        scroll.setOpaque(false);
        scroll.getViewport().setOpaque(false);
        scroll.getVerticalScrollBar().setUnitIncrement(14);
    }

    public static void styleList(JList<String> list) {
        list.setBackground(Theme.BG_CARD);
        list.setForeground(Theme.TEXT_LIGHT);
        list.setFont(Theme.SUBTITLE_FONT);
        list.setSelectionBackground(Theme.GOLD_DARK);
        list.setSelectionForeground(Theme.TEXT_LIGHT);
        list.setFixedCellHeight(26);
        list.setBorder(BorderFactory.createEmptyBorder(6, 10, 6, 10));
        list.setCellRenderer(new DefaultListCellRenderer() {
            @Override
            public Component getListCellRendererComponent(JList<?> l, Object value, int index,
                    boolean isSelected, boolean cellHasFocus) {
                Component c = super.getListCellRendererComponent(l, value, index, isSelected, cellHasFocus);
                c.setBackground(isSelected ? Theme.GOLD_DARK : Theme.BG_CARD);
                c.setForeground(Theme.TEXT_LIGHT);
                ((javax.swing.JComponent) c).setBorder(BorderFactory.createEmptyBorder(4, 6, 4, 6));
                return c;
            }
        });
    }
}
