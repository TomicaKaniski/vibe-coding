# DHL Shipment Tracker (PowerShell)

PowerShell script to track DHL shipments using the official DHL Germany API. It shows detailed shipment status, ICE code explanations, and historical tracking events in a clean, formatted output.  
  
Vibe-coded with the help of ChatGPT (OpenAI), during a rainy, summer day of 2025.

## ✨ Features

- 💡 Highlights current status with timestamp
- 📜 Shows historical tracking events
- 🔍 Resolves status codes from ICE event CSV lookup
- 🌐 Cleans up HTML in API responses
- ✅ Uses approved PowerShell verbs
- 🧩 Easily configurable via parameters

## 🛠 Requirements

- PowerShell 5.1+ or newer
- A DHL API key from [DHL Developer Portal](https://developer.dhl.com)
  - help is available at [DHL Developer Portal - Getting Started](https://developer.dhl.com/api-reference/shipment-tracking#get-started-section/)
- CSV lookup file:
  -  with headers: `ice_event_code`, `ice_ric_code`, `ttpro_event_code`, `ice_ric_name`, `ice_event_name`, `ttpro_event_code_meaning`
  - repo version downloaded from [DHL Developer Portal - API Reference](https://developer.dhl.com/api-reference/dhl-paket-de-sendungsverfolgung-post-paket-deutschland?language_content_entity=de&lang=de#get-started-section/), and is **property of DHL**
- Tracking number text file (one per line)
  - attached sample contains imaginary tracking numbers
- All parameters are optional thanks to sensible defaults

## 🚀 Usage

```powershell
.\Track-DHLShipment.ps1 `
  -apiKey "YOUR_API_KEY" `
  -trackingFile ".\tracking-numbers.txt" `
  -csvPath ".\ICE_Event_RIC_Kombinationen.csv" `
  -apiBaseUrl "https://api-eu.dhl.com/track/shipments?trackingNumber="
```

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
