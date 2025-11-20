import os
import re
import json
import logging
from typing import Any, Dict, List
import requests
import win32com.client
from dotenv import load_dotenv
from tqdm import tqdm
from scribe import logger
from config import MODEL_NAME, DRY_RUN, BATCH_SIZE

# Load environment variables
load_dotenv()
OLLAMA_URL: str = os.getenv("OLLAMA_URL", "")  # e.g., https://openwebui.ai.tklabs.eu/api/chat/completions
API_KEY: str = os.getenv("API_KEY", "")        # Your OpenWebUI API key

HEADERS: Dict[str, str] = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# Allowed categories
ALLOWED_CATEGORIES = ["Work", "Personal", "Finance", "Newsletter", "Social", "To-Do", "Spam", "Unknown", "Photo"]


# -----------------------
# Category Utilities
# -----------------------
def parse_model_response(raw_response: Dict[str, Any]) -> Dict[str, Any]:
    """Extract category JSON from AI output, handle YAML-ish or messy JSON."""
    try:
        choices: List[Dict[str, Any]] = raw_response.get("choices", [])
        if not choices:
            return {"category": "Unknown", "priority": 1, "short_summary": ""}

        content_str: str = choices[0].get("message", {}).get("content", "").strip()
        content_str = re.sub(r"(?m)^-\s*", "", content_str)

        try:
            classification: Dict[str, Any] = json.loads(content_str)
        except json.JSONDecodeError:
            classification = {}
            for line in content_str.splitlines():
                if ":" not in line:
                    continue
                k, v = line.split(":", 1)
                k = k.strip().strip('"')
                v = v.strip().strip('"')
                if k == "priority":
                    try:
                        v = int(v)
                    except ValueError:
                        v = 1
                classification[k] = v

            classification.setdefault("category", "Unknown")
            classification.setdefault("priority", 1)
            classification.setdefault("short_summary", "")

        return classification

    except Exception as e:
        logging.warning(f"Failed to parse model response: {e}")
        return {"category": "Unknown", "priority": 1, "short_summary": ""}


def sanitize_category_name(name: str) -> str:
    """Remove forbidden characters for Outlook categories, keep content."""
    if not name:
        return "Misc"
    return re.sub(r"[\[\]_,#]", "", name.strip()) or "Misc"


def email_already_categorized(msg: Any) -> bool:
    """Check if the email already has one of the allowed categories."""
    try:
        categories: List[str] = [c.strip() for c in (msg.Categories or "").split(",")]
        for cat in categories:
            if cat in ALLOWED_CATEGORIES:
                return True
        return False
    except Exception as e:
        logger.warning(f"Failed to check categories for email '{getattr(msg, 'Subject', '')}': {e}")
        return False


def tag_email_category(msg: Any, category: str) -> None:
    """Apply category safely, skip if already present."""
    safe_cat: str = sanitize_category_name(category)
    try:
        existing: List[str] = [c.strip() for c in (msg.Categories or "").split(",")]
        if safe_cat in existing:
            return
        if not DRY_RUN:
            msg.Categories = ", ".join(existing + [safe_cat]) if existing else safe_cat
            msg.Save()
        logger.info(f"[CATEGORIZED] '{getattr(msg, 'Subject', '')}' as '{safe_cat}'")
    except Exception as e:
        logger.error(f"Failed to tag email '{getattr(msg, 'Subject', '')}' with category '{safe_cat}': {e}")


# -----------------------
# AI Classification
# -----------------------
def classify_batch(emails: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    results: List[Dict[str, Any]] = []
    for e in emails:
        data: Dict[str, Any] = {
            "model": MODEL_NAME,
            "messages": [{
                "role": "user",
                "content": f"""You are an email classification assistant.
Classify the following email. Return ONLY a JSON object with keys:
- priority: 1-5
- category: one of {ALLOWED_CATEGORIES}
- short_summary: one sentence summary

Email Subject: {e['subject']}
Email Body: {e['body']}
"""
            }]
        }
        try:
            resp = requests.post(OLLAMA_URL, json=data, headers=HEADERS, timeout=60)
            resp.raise_for_status()
            classification = parse_model_response(resp.json())
            results.append(classification)
        except Exception as ex:
            logger.warning(f"Failed to classify email '{e['subject']}': {ex}")
            results.append({"category": "Unknown", "priority": 1, "short_summary": ""})
    return results


# -----------------------
# Main Inbox Processing
# -----------------------
def process_inbox() -> None:
    try:
        outlook = win32com.client.Dispatch("Outlook.Application").GetNamespace("MAPI")
        inbox = outlook.GetDefaultFolder(6)  # Inbox
    except Exception as e:
        logger.critical(f"Outlook COM init failed: {e}")
        return

    try:
        messages = inbox.Items
        messages.Sort("ReceivedTime", True)
    except Exception as e:
        logger.error(f"Inbox retrieval failed: {e}")
        return

    batch: List[Dict[str, Any]] = []
    id_counter: int = 1
    msg_map: Dict[int, Any] = {}

    total_emails: int = len(messages)
    logger.info(f"Processing {total_emails} emails in Inbox...")

    for msg in tqdm(list(messages), desc="Processing emails", unit="email"):
        try:
            subject: str = msg.Subject or ""
            body: str = msg.Body or ""
        except Exception as e:
            logger.warning(f"Skipping message (read error): {e}")
            continue

        if email_already_categorized(msg):
            logger.debug(f"Skipping already categorized email: {subject}")
            continue

        batch.append({"id": id_counter, "subject": subject, "body": body})
        msg_map[id_counter] = msg
        id_counter += 1

        if len(batch) >= BATCH_SIZE:
            results: List[Dict[str, Any]] = classify_batch(batch)
            for i, result in enumerate(results):
                email_id: int = batch[i]["id"]
                original_msg: Any = msg_map[email_id]
                tag_email_category(original_msg, result.get("category", "Unknown"))
                logger.info(f"[{result.get('priority', 1)}] {result.get('category', 'Unknown')} – {batch[i]['subject']}")
                logger.info(f"Summary: {result.get('short_summary', '')}")
            batch = []

    # Process remaining emails
    if batch:
        results = classify_batch(batch)
        for i, result in enumerate(results):
            email_id: int = batch[i]["id"]
            original_msg: Any = msg_map[email_id]
            tag_email_category(original_msg, result.get("category", "Unknown"))
            logger.info(f"[{result.get('priority', 1)}] {result.get('category', 'Unknown')} – {batch[i]['subject']}")
            logger.info(f"Summary: {result.get('short_summary', '')}")

    logger.info("Inbox processing complete!")


# -----------------------
# Entry Point
# -----------------------
if __name__ == "__main__":
    process_inbox()
