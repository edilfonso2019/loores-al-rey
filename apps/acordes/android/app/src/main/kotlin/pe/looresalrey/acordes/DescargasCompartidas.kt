package pe.looresalrey.acordes

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException

/**
 * Descargas compartidas entre las apps de la familia Loores al Rey
 * (Loores al Rey y Acordes IASDMR): si una ya descargó una pista o partitura,
 * la otra la usa sin volver a descargarla.
 *
 * Seguridad: el proveedor solo deja LEER, y solo a apps que tienen el permiso
 * `pe.looresalrey.permission.DESCARGAS`, que es de nivel "signature": Android
 * solo lo concede a apps firmadas con la misma llave. Las rutas se validan
 * (himnario/tipo/número.ext) para que no se pueda pedir nada fuera de `descargas/`.
 */
object DescargasCompartidas {
    /** Proveedores de la familia; cada app consulta los que no son suyos. */
    val AUTORIDADES = listOf("pe.looresalrey.app.descargas", "pe.looresalrey.acordes.descargas")
    const val CANAL = "pe.looresalrey/descargas_compartidas"

    private val LIBRO = Regex("^[a-z]{1,20}$")
    private val TIPO = Regex("^(instrumental|cantado|partitura)$")
    private val ARCHIVO = Regex("^[0-9]{1,5}\\.(mp3|pdf)$")

    /** Las mismas raíces que usa MediaService (path_provider). */
    fun raices(context: Context): List<File> =
        listOf(File(context.getDir("flutter", Context.MODE_PRIVATE), "descargas")) +
            context.getExternalFilesDirs(null).filterNotNull().map { File(it, "descargas") }

    fun rutaValida(segmentos: List<String>): Boolean =
        segmentos.size == 3 && LIBRO.matches(segmentos[0]) &&
            TIPO.matches(segmentos[1]) && ARCHIVO.matches(segmentos[2])

    fun buscar(context: Context, segmentos: List<String>): File? {
        if (!rutaValida(segmentos)) return null
        return raices(context)
            .map { File(it, segmentos.joinToString(File.separator)) }
            .firstOrNull { it.isFile }
    }

    /** Canal para que Flutter liste y lea las descargas de la otra app. */
    fun registrar(engine: FlutterEngine, context: Context) {
        val propia = "${context.packageName}.descargas"
        val main = Handler(Looper.getMainLooper())
        MethodChannel(engine.dartExecutor.binaryMessenger, CANAL).setMethodCallHandler { call, result ->
            when (call.method) {
                "listar" -> Thread {
                    val filas = mutableListOf<Map<String, Any>>()
                    for (autoridad in AUTORIDADES) {
                        if (autoridad == propia) continue
                        try {
                            context.contentResolver.query(
                                Uri.parse("content://$autoridad/lista"), null, null, null, null,
                            )?.use { c ->
                                while (c.moveToNext()) {
                                    filas.add(mapOf("autoridad" to autoridad, "ruta" to c.getString(0), "bytes" to c.getLong(1)))
                                }
                            }
                        } catch (_: Exception) {
                            // La otra app no está instalada o no tiene la misma firma.
                        }
                    }
                    main.post { result.success(filas) }
                }.start()
                "leer" -> {
                    val autoridad = call.argument<String>("autoridad")
                    val ruta = call.argument<String>("ruta")
                    if (autoridad == null || ruta == null || autoridad !in AUTORIDADES ||
                        !rutaValida(ruta.split("/"))
                    ) {
                        result.error("ruta", "Ruta no válida", null)
                    } else {
                        Thread {
                            try {
                                val bytes = context.contentResolver
                                    .openInputStream(Uri.parse("content://$autoridad/$ruta"))
                                    ?.use { it.readBytes() }
                                main.post { result.success(bytes) }
                            } catch (e: Exception) {
                                main.post { result.error("leer", e.message, null) }
                            }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

/** Presta (solo lectura) las descargas de esta app a las apps de la familia. */
class DescargasProvider : ContentProvider() {
    override fun onCreate() = true

    override fun query(
        uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?,
    ): Cursor {
        val ctx = context ?: throw IllegalStateException()
        if (uri.pathSegments != listOf("lista")) throw IllegalArgumentException("URI no válida")
        val cursor = MatrixCursor(arrayOf("ruta", "bytes"))
        for (raiz in DescargasCompartidas.raices(ctx)) {
            raiz.listFiles()?.forEach { libro ->
                libro.listFiles()?.forEach { tipo ->
                    tipo.listFiles()?.forEach { f ->
                        val segs = listOf(libro.name, tipo.name, f.name)
                        if (f.isFile && DescargasCompartidas.rutaValida(segs)) {
                            cursor.addRow(arrayOf<Any>(segs.joinToString("/"), f.length()))
                        }
                    }
                }
            }
        }
        return cursor
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("Solo lectura")
        val ctx = context ?: throw FileNotFoundException()
        val f = DescargasCompartidas.buscar(ctx, uri.pathSegments) ?: throw FileNotFoundException(uri.path)
        return ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri): String? = when (uri.lastPathSegment?.substringAfterLast('.')) {
        "mp3" -> "audio/mpeg"
        "pdf" -> "application/pdf"
        else -> null
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException()
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int =
        throw UnsupportedOperationException()
    override fun update(
        uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?,
    ): Int = throw UnsupportedOperationException()
}
