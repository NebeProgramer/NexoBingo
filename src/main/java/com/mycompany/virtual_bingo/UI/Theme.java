/*
 * Paleta visual compartida por las interfaces de servidor y cliente,
 * para que ambas se vean consistentes y no como un formulario de oficina.
 */
package com.mycompany.virtual_bingo.UI;

import java.awt.Color;
import java.awt.Font;

public final class Theme {

    private Theme() {
    }

    // Fondo tipo "sala de juegos" nocturna, con acentos dorados.
    public static final Color BG_DARK = new Color(0x101823);
    public static final Color BG_PANEL = new Color(0x18233A);
    public static final Color BG_CARD = new Color(0x1F2C47);
    public static final Color BORDER = new Color(0x2C3B5C);

    public static final Color GOLD = new Color(0xF2B705);
    public static final Color GOLD_DARK = new Color(0xC79300);

    public static final Color TEXT_LIGHT = new Color(0xF3F5F9);
    public static final Color TEXT_MUTED = new Color(0x8C9AB4);

    public static final Color GREEN = new Color(0x2ECC71);
    public static final Color RED = new Color(0xE8534B);
    public static final Color BLUE = new Color(0x4AA3F0);
    public static final Color ORANGE = new Color(0xF08A3C);
    public static final Color PURPLE = new Color(0xB673E0);

    public static final Font TITLE_FONT = new Font("SansSerif", Font.BOLD, 26);
    public static final Font SUBTITLE_FONT = new Font("SansSerif", Font.PLAIN, 13);
    public static final Font SECTION_FONT = new Font("SansSerif", Font.BOLD, 13);
    public static final Font BUTTON_FONT = new Font("SansSerif", Font.BOLD, 14);
    public static final Font BALL_FONT = new Font("SansSerif", Font.BOLD, 15);
    public static final Font LETTER_FONT = new Font("SansSerif", Font.BOLD, 22);
    public static final Font MONO_FONT = new Font(Font.MONOSPACED, Font.PLAIN, 13);

    /** Color de acento tradicional de bingo para cada columna. */
    public static Color letterColor(String letter) {
        return switch (letter) {
            case "B" -> RED;
            case "I" -> ORANGE;
            case "N" -> GREEN;
            case "G" -> BLUE;
            case "O" -> PURPLE;
            default -> GOLD;
        };
    }

    private static java.util.List<java.awt.Image> appIcons;

    /**
     * Aplica el logo de NexoBingo como ícono de la ventana (barra de
     * título Y barra de tareas). Se cargan varios tamaños desde
     * src/main/resources/icons/ para que Windows/Linux elijan la
     * resolución que mejor les quede en cada contexto (barra de tareas
     * vs Alt+Tab vs esquina de la ventana), en vez de escalar una sola
     * imagen y verse borrosa.
     */
    public static void applyAppIcon(java.awt.Window window) {
        if (appIcons == null) {
            appIcons = new java.util.ArrayList<>();
            for (String name : new String[]{"nexobingo-icon-32.png", "nexobingo-icon-64.png",
                    "nexobingo-icon-256.png"}) {
                java.net.URL url = Theme.class.getResource("/icons/" + name);
                if (url != null) {
                    appIcons.add(new javax.swing.ImageIcon(url).getImage());
                }
            }
        }
        if (appIcons.isEmpty()) {
            return; // no se encontraron los recursos; se deja el ícono por defecto
        }
        if (window instanceof java.awt.Frame frame) {
            frame.setIconImages(appIcons);
        } else if (window instanceof java.awt.Dialog dialog) {
            dialog.setIconImages(appIcons);
        }
    }
}
