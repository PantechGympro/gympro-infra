#!/usr/bin/env python3
"""
dora.py — Métricas DORA a partir del historial de GitHub Actions (SCRUM-182, métricas).

Para cada repo toma las ejecuciones del workflow de despliegue y calcula:
  · Frecuencia de despliegue   despliegues exitosos por semana
  · Lead time for changes      mediana de (fin del despliegue − fecha del commit)
  · Change failure rate        % de despliegues que fallaron
  · MTTR                       mediana de (fallo → siguiente despliegue exitoso)

Uso:
  python3 dora.py --owner PantechGympro --repos gympro-api gympro-web gympro-infra \
                  --workflow deploy-prod.yml --days 30 [--json salida.json]
  python3 dora.py --entrada runs.json --days 30      # sin red (pruebas)

Requiere la CLI `gh` autenticada (GH_TOKEN) con lectura de Actions de cada repo.
Solo cuentan ejecuciones terminadas en success/failure: cancelled/skipped (p. ej. fuera
de la ventana horaria o sin aprobación) no son ni éxito ni fallo del cambio.
"""
import argparse
import json
import statistics
import subprocess
import sys
from datetime import datetime, timedelta, timezone


def _t(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")) if s else None


def calcular(runs, desde, hasta=None):
    """runs: lista de dicts de la API de GitHub (workflow runs). Devuelve las 4 métricas."""
    hasta = hasta or datetime.now(timezone.utc)
    validos = sorted(
        (r for r in runs if r.get("conclusion") in ("success", "failure") and _t(r.get("created_at"))),
        key=lambda r: _t(r["created_at"]),
    )
    en_periodo = [r for r in validos if desde <= _t(r["created_at"]) <= hasta]
    exitos = [r for r in en_periodo if r["conclusion"] == "success"]
    fallos = [r for r in en_periodo if r["conclusion"] == "failure"]

    semanas = max((hasta - desde).days / 7, 1e-9)
    leads = []
    for r in exitos:
        commit = (r.get("head_commit") or {}).get("timestamp")
        fin = _t(r.get("updated_at"))
        if commit and fin:
            leads.append((fin - _t(commit)).total_seconds() / 3600)

    # MTTR: sobre TODO el historial (un fallo del periodo puede resolverse después).
    recuperaciones, pendiente = [], None
    for r in validos:
        t = _t(r["created_at"])
        if r["conclusion"] == "failure" and pendiente is None:
            pendiente = t
        elif r["conclusion"] == "success" and pendiente is not None:
            if desde <= pendiente <= hasta:
                recuperaciones.append((t - pendiente).total_seconds() / 3600)
            pendiente = None

    total = len(exitos) + len(fallos)
    return {
        "despliegues_exitosos": len(exitos),
        "despliegues_fallidos": len(fallos),
        "frecuencia_por_semana": round(len(exitos) / semanas, 2),
        "lead_time_horas_mediana": round(statistics.median(leads), 1) if leads else None,
        "change_failure_rate_pct": round(100 * len(fallos) / total, 1) if total else None,
        "mttr_horas_mediana": round(statistics.median(recuperaciones), 1) if recuperaciones else None,
    }


def _gh_runs(owner, repo, workflow):
    out = subprocess.run(
        ["gh", "api", "--paginate", f"repos/{owner}/{repo}/actions/workflows/{workflow}/runs?per_page=100&status=completed",
         "--jq", ".workflow_runs[]"],
        capture_output=True, text=True, check=True,
    ).stdout
    return [json.loads(linea) for linea in out.splitlines() if linea.strip()]


def _fmt(v, sufijo=""):
    return "—" if v is None else f"{v}{sufijo}"


def tabla_markdown(resultados, dias, workflow):
    filas = [
        f"### Métricas DORA — últimos {dias} días (`{workflow}`)",
        "",
        "| Repo | Despliegues ✅ | Fallidos ❌ | Frecuencia / semana | Lead time (mediana) | Change failure rate | MTTR (mediana) |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for repo, m in resultados.items():
        filas.append(
            f"| {repo} | {m['despliegues_exitosos']} | {m['despliegues_fallidos']} | {m['frecuencia_por_semana']} | "
            f"{_fmt(m['lead_time_horas_mediana'], ' h')} | {_fmt(m['change_failure_rate_pct'], ' %')} | {_fmt(m['mttr_horas_mediana'], ' h')} |"
        )
    filas += ["", "_Cuentan solo ejecuciones terminadas en éxito o fallo. «—» = sin datos suficientes en el periodo._"]
    return "\n".join(filas)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--owner", default="PantechGympro")
    ap.add_argument("--repos", nargs="*", default=["gympro-api", "gympro-web", "gympro-infra"])
    ap.add_argument("--workflow", default="deploy-prod.yml")
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--entrada", help="JSON {repo: [runs]} en lugar de consultar a GitHub")
    ap.add_argument("--json", dest="salida_json")
    a = ap.parse_args(argv)

    hasta = datetime.now(timezone.utc)
    desde = hasta - timedelta(days=a.days)
    if a.entrada:
        datos = json.load(open(a.entrada, encoding="utf-8"))
    else:
        datos = {r: _gh_runs(a.owner, r, a.workflow) for r in a.repos}
    resultados = {repo: calcular(runs, desde, hasta) for repo, runs in datos.items()}

    print(tabla_markdown(resultados, a.days, a.workflow))
    if a.salida_json:
        json.dump(resultados, open(a.salida_json, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
