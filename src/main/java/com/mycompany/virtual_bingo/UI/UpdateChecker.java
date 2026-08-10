/*
 * Chequeo de actualizaciones: consulta la API de GitHub (releases/latest)
 * del repo del proyecto y, si hay una versión más nueva que la actual,
 * muestra un diálogo con un botón que lleva a la página de descarga.
 *
 * No usa ninguna librería de JSON (el proyecto no tiene dependencias
 * externas a propósito): se extrae el campo "tag_name" con una búsqueda
 * de texto simple sobre la respuesta cruda de la API, suficiente porque
 * el formato de ese campo en la respuesta de GitHub es estable.
 */
package com.mycompany.virtual_bingo.UI;

import java.awt.Component;
import java.awt.Desktop;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URI;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import javax.swing.JOptionPane;
import javax.swing.SwingUtilities;

public class UpdateChecker {

    private static final String API_URL =
            "https://api.github.com/repos/NebeProgramer/NexoBingo/releases/latest";

    // Entrada de descarga: la página del portafolio, no el link crudo de GitHub.
    // TODO Anderson: actualiza este link cuando corrijas el del portafolio.
    private static final String LINK_DESCARGA =
            "https://repositorio-aeop.onrender.com/desktop/VirtualBingo";

    private UpdateChecker() {
    }

    /**
     * Lanza el chequeo en segundo plano. Si hay una versión nueva, muestra
     * el diálogo en el hilo de Swing. Si no hay internet, la API falla, o
     * el repo todavía no tiene ningún release publicado, no hace nada
     * (falla en silencio a propósito, para no molestar al usuario).
     *
     * @param padre ventana sobre la que centrar el diálogo (puede ser null)
     */
    public static void verificar(Component padre) {
        new Thread(() -> {
            try {
                String versionActual = obtenerVersionActual();
                if (versionActual == null) {
                    // Corriendo desde NetBeans/clases sueltas (sin jar empaquetado):
                    // no hay manifest del que leer la versión, así que no hay con
                    // qué comparar. No molestar.
                    return;
                }

                String json = obtenerJson(API_URL);
                String tag = extraerCampo(json, "tag_name");
                if (tag == null) {
                    return;
                }

                String ultimaVersion = tag.startsWith("v") ? tag.substring(1) : tag;
                if (!ultimaVersion.equals(versionActual)) {
                    SwingUtilities.invokeLater(() -> mostrarDialogo(padre, tag));
                }
            } catch (Exception e) {
                // Sin internet, timeout, o error de la API: no molestar.
            }
        }, "UpdateChecker").start();
    }

    /**
     * Lee la versión actual desde el manifest del jar (Implementation-Version,
     * puesta ahí por el pom.xml al empaquetar). Devuelve null si se está
     * corriendo desde NetBeans/clases sueltas, donde no existe ese manifest.
     */
    private static String obtenerVersionActual() {
        Package pkg = UpdateChecker.class.getPackage();
        return (pkg != null) ? pkg.getImplementationVersion() : null;
    }

    private static String obtenerJson(String urlStr) throws Exception {
        URL url = new URI(urlStr).toURL();
        HttpURLConnection con = (HttpURLConnection) url.openConnection();
        con.setRequestProperty("Accept", "application/vnd.github+json");
        con.setConnectTimeout(4000);
        con.setReadTimeout(4000);

        // 404 = repo sin releases todavía; cualquier otro código != 200 lo
        // tratamos igual: no hay dato confiable para comparar.
        if (con.getResponseCode() != 200) {
            return null;
        }

        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(
                new InputStreamReader(con.getInputStream(), StandardCharsets.UTF_8))) {
            String linea;
            while ((linea = br.readLine()) != null) {
                sb.append(linea);
            }
        }
        return sb.toString();
    }

    private static String extraerCampo(String json, String campo) {
        if (json == null) {
            return null;
        }
        String buscar = "\"" + campo + "\":\"";
        int inicio = json.indexOf(buscar);
        if (inicio == -1) {
            return null;
        }
        inicio += buscar.length();
        int fin = json.indexOf('"', inicio);
        if (fin == -1) {
            return null;
        }
        return json.substring(inicio, fin);
    }

    private static void mostrarDialogo(Component padre, String versionNueva) {
        int opcion = JOptionPane.showConfirmDialog(padre,
                "Hay una nueva versión disponible: " + versionNueva
                        + "\n¿Deseas ir a la página de descarga?",
                "Actualización disponible",
                JOptionPane.YES_NO_OPTION,
                JOptionPane.INFORMATION_MESSAGE);

        if (opcion == JOptionPane.YES_OPTION) {
            try {
                Desktop.getDesktop().browse(new URI(LINK_DESCARGA));
            } catch (Exception ex) {
                // No se pudo abrir el navegador; no hay mucho más que hacer.
            }
        }
    }
}
