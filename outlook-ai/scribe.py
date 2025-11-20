# scribe.py
# Centralized Rich logging setup for the Outlook AI project

import logging
from rich.console import Console
from rich.logging import RichHandler
from config import LOG_LEVEL

# Create console for pretty output
console = Console()

# Configure logging
logging.basicConfig(
    level=LOG_LEVEL,
    format="%(message)s",
    datefmt="[%X]",
    handlers=[RichHandler(console=console)]
)

logger = logging.getLogger("outlook-ai")
