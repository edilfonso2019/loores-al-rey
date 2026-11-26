package pe.looresalrey.app

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Pistas y partituras ya descargadas por Acordes IASDMR.
        DescargasCompartidas.registrar(flutterEngine, applicationContext)
    }
}
