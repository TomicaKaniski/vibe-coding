# config.py
# Centralized configuration loader for the Outlook AI project.

import os
from dotenv import load_dotenv

# Load .env file
load_dotenv()

# Ollama configuration
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434")
MODEL_NAME = os.getenv("MODEL_NAME", "mistral:instruct")

# Application behavior settings
BATCH_SIZE = int(os.getenv("BATCH_SIZE", 1))  # future use
DRY_RUN = os.getenv("DRY_RUN", "false").lower() == "true"

# Logging settings
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
