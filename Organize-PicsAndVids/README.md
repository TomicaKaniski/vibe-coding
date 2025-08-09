# Pics and Videos Organizer (PowerShell)

PowerShell script to automatically organize your pictures and videos into folders named by their creation or metadata date — cleanly sorting your media by day with minimal hassle.  

Vibe-coded with the help of ChatGPT (OpenAI), during a bright, organized summer evening of 2025.

## ✨ Features

- 📂 Sorts JPG, JPEG, PNG, and MP4 files by date into `yyyyMMdd` folders  
- 🕵️‍♂️ Extracts EXIF Date Taken metadata for images  
- 🖥 Uses Windows Shell metadata for video creation dates  
- 🛠 Falls back on file system dates if metadata missing  
- 📝 Logs operations with timestamps and color-coded console output  
- 🚫 Skips files if the destination file already exists to prevent overwrite  
- 🎛️ Runs with a simple `-SourceFolder` parameter for flexible usage  

## 🛠 Requirements

- PowerShell 5.1 or newer  
- Windows OS (uses COM object for video metadata)  
- No external modules required, uses built-in .NET `System.Drawing`  

## 🚀 Usage

```powershell
.\Organize-PicsAndVids.ps1 -SourceFolder "C:\Path\To\Your\Pictures"
```

## ✍️ Authors
🧑‍💻 Tomica Kaniski  
🤖 ChatGPT (OpenAI)

## 📜 License
This project is licensed under the [WTFPL License](http://www.wtfpl.net) – feel free to use, modify, and share.  

<center><a href="http://www.wtfpl.net/"><img src="http://www.wtfpl.net/wp-content/uploads/2012/12/wtfpl-badge-4.png" width="80" height="15" alt="WTFPL" /></a></center>
