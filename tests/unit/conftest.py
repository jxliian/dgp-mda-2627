"""Configuración común de las pruebas unitarias del backend.

Se ejecuta automáticamente antes de las pruebas (pytest la busca por su nombre).
"""
import os
import sys
from pathlib import Path

# Clave solo para las pruebas: así no dependen del .env de cada uno.
os.environ.setdefault("JWT_SECRET_KEY", "clave-solo-para-tests-" + "x" * 32)

# Permite importar main, auth, DB... desde la carpeta del backend.
BACKEND_DIR = Path(__file__).resolve().parents[2] / "src" / "backend" / "proyectFastAPI"
sys.path.insert(0, str(BACKEND_DIR))