import os
from pathlib import Path
from dotenv import load_dotenv

# .env fica dentro de pipeline/ junto com o restante da aplicação
BASE_DIR = Path(__file__).parent.parent
load_dotenv(Path(__file__).parent / ".env")

RESULTS_DIR = BASE_DIR / os.getenv("RESULTS_DIR", "results")
CONFIGS_DIR = BASE_DIR / os.getenv("CONFIGS_DIR", "auto-bash/configs")
DATA_DIR = BASE_DIR / os.getenv("DATA_DIR", "data")

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/mpb")

GOOGLE_CREDENTIALS_FILE = os.getenv("GOOGLE_CREDENTIALS_FILE")
SPREADSHEET_ID = os.getenv("SPREADSHEET_ID", "162p_HpQWQt6OYtroJY_0uXuO3-WnVste8Mnd4YXGg10")
METADATA_SHEET = os.getenv("METADATA_SHEET", "Metadata - Bacteria")
