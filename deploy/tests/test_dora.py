import os
import sys
import unittest
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import dora  # noqa: E402

HASTA = datetime(2026, 11, 30, 12, 0, tzinfo=timezone.utc)
DESDE = HASTA - timedelta(days=28)          # 4 semanas exactas


def run(dias_atras, conclusion, commit_horas_antes=2.0, duracion_min=5):
    inicio = HASTA - timedelta(days=dias_atras)
    return {
        "conclusion": conclusion,
        "created_at": inicio.isoformat(),
        "updated_at": (inicio + timedelta(minutes=duracion_min)).isoformat(),
        "head_commit": {"timestamp": (inicio - timedelta(hours=commit_horas_antes)).isoformat()},
    }


class TestCalcular(unittest.TestCase):
    def test_frecuencia_y_tasa_de_fallo(self):
        runs = [run(20, "success"), run(14, "success"), run(7, "success"), run(3, "failure")]
        m = dora.calcular(runs, DESDE, HASTA)
        self.assertEqual((m["despliegues_exitosos"], m["despliegues_fallidos"]), (3, 1))
        self.assertEqual(m["frecuencia_por_semana"], 0.75)
        self.assertEqual(m["change_failure_rate_pct"], 25.0)

    def test_cancelados_y_omitidos_no_cuentan(self):
        runs = [run(10, "success"), run(9, "cancelled"), run(8, "skipped"), run(7, None)]
        m = dora.calcular(runs, DESDE, HASTA)
        self.assertEqual(m["despliegues_exitosos"] + m["despliegues_fallidos"], 1)
        self.assertEqual(m["change_failure_rate_pct"], 0.0)

    def test_lead_time_es_mediana_en_horas(self):
        runs = [run(10, "success", commit_horas_antes=1, duracion_min=0),
                run(9, "success", commit_horas_antes=3, duracion_min=0),
                run(8, "success", commit_horas_antes=100, duracion_min=0)]
        self.assertEqual(dora.calcular(runs, DESDE, HASTA)["lead_time_horas_mediana"], 3.0)

    def test_mttr_fallo_hasta_siguiente_exito(self):
        runs = [run(10, "success"), run(6, "failure"), run(6 - 0.5, "success")]   # recupera en 12 h
        self.assertEqual(dora.calcular(runs, DESDE, HASTA)["mttr_horas_mediana"], 12.0)

    def test_fallos_consecutivos_miden_desde_el_primero(self):
        runs = [run(6, "failure"), run(5, "failure"), run(4, "success")]          # 2 días = 48 h
        self.assertEqual(dora.calcular(runs, DESDE, HASTA)["mttr_horas_mediana"], 48.0)

    def test_sin_datos_devuelve_none_sin_dividir_entre_cero(self):
        m = dora.calcular([], DESDE, HASTA)
        self.assertIsNone(m["change_failure_rate_pct"])
        self.assertIsNone(m["lead_time_horas_mediana"])
        self.assertIsNone(m["mttr_horas_mediana"])
        self.assertEqual(m["frecuencia_por_semana"], 0.0)

    def test_fuera_del_periodo_se_ignora(self):
        m = dora.calcular([run(60, "success"), run(5, "success")], DESDE, HASTA)
        self.assertEqual(m["despliegues_exitosos"], 1)

    def test_tabla_markdown_tiene_una_fila_por_repo(self):
        res = {"gympro-api": dora.calcular([run(5, "success")], DESDE, HASTA),
               "gympro-web": dora.calcular([], DESDE, HASTA)}
        md = dora.tabla_markdown(res, 28, "deploy-prod.yml")
        self.assertIn("| gympro-api | 1 |", md)
        self.assertIn("| gympro-web | 0 |", md)
        self.assertIn("—", md)


if __name__ == "__main__":
    unittest.main()
