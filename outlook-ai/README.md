# Outlook AI - Email Categorizer

This project automatically categorizes emails in your Outlook Inbox using
an AI model (Ollama/OpenWebUI). Emails are tagged with categories such
as **Work**, **Personal**, **Finance**, **Newsletter**, **Social**,
**To‑Do**, **Spam**, or **Unknown**.

## Features

-   AI‑powered email classification
-   Batch processing for efficiency
-   Safe tagging of Outlook emails
-   Retry logic for API failures
-   Debug logging of raw AI responses

## Requirements

-   **Windows** (required for Outlook COM interface)
-   **Outlook desktop client installed**
-   **Python 3.11+**

## Installation

### 1. Clone the repository

``` bash
git clone https://github.com/TomicaKaniski/vibe-coding/
cd outlook-ai
```

### 2. Create a virtual environment

``` bash
python -m venv venv
```

### 3. Activate the virtual environment

Windows:

``` bash
venv\Scripts\activate
```

macOS/Linux:

``` bash
source venv/bin/activate
```

### 4. Install dependencies

``` bash
pip install -r requirements.txt
```

### 5. Create a `.env` file in the project root

``` dotenv
OLLAMA_URL=https://your-openwebui-or-ollama-endpoint/api/chat/completions
API_KEY=your_api_key_here
MODEL_NAME=mistral:instruct
BATCH_SIZE=1
DRY_RUN=true
LOG_LEVEL=INFO
```

Set `DRY_RUN=false` to actually apply categories to emails.

## Usage

``` bash
python main.py
```

The script will: - Read all uncategorized emails in your Outlook Inbox
- Classify each email with AI
- Apply the category (unless `DRY_RUN=true`)
- Log output to the console

## Notes

-   Only uncategorized emails are processed.
-   Ensure your AI endpoint and API key are valid.
-   Adjust `BATCH_SIZE` for large inboxes.
-   Logging level can be changed via `.env`.

## ✍️ Authors
🧑‍💻 Tomica Kaniski  
🤖 ChatGPT (OpenAI)

## 📜 License
This project is licensed under the [WTFPL License](http://www.wtfpl.net) – feel free to use, modify, and share.  

<p align="center">
  <a href="https://www.wtfpl.net/">
    <img src="https://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl-badge-4.png" width="80" height="15" alt="WTFPL" />
  </a>
</p>
