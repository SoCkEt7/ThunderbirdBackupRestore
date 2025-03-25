# 🦊 Thunderbird Complete Backup Tool 📬

<div align="center">
<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/e/e1/Thunderbird_Logo%2C_2018.svg/200px-Thunderbird_Logo%2C_2018.svg.png" width="120" alt="Thunderbird Logo">
</div>

**Auteur / Author**: Antonin Nvh

---

## Français 🇫🇷

### 📋 Description

Un outil complet de sauvegarde pour Mozilla Thunderbird qui permet d'exporter tous les paramètres, comptes, messages, filtres, mots de passe, signatures et autres configurations.

Ce script bash fonctionne sur Linux, macOS et Windows (via Git Bash ou WSL) et crée une sauvegarde complète de votre profil Thunderbird.

### ✨ Fonctionnalités

- Sauvegarde de plusieurs profils Thunderbird
- Exportation des comptes email et leurs configurations
- Sauvegarde des messages (locaux et IMAP mis en cache)
- Conservation des filtres de messages et règles
- Exportation des mots de passe et informations de connexion
- Sauvegarde des signatures (tous formats)
- Exportation des carnets d'adresses
- Sauvegarde des données de calendrier (si vous utilisez l'extension Lightning)
- Conservation des extensions et add-ons
- Sauvegarde des préférences et personnalisations
- Détection intelligente des profils
- Estimation de la taille avant sauvegarde
- Option de sauvegarde incrémentale
- Script de restauration inclus

### 📦 Contenu de la sauvegarde

- Dossiers de profil (contenant comptes, messages, filtres, etc.)
- Bases de données de mots de passe et identifiants enregistrés
- Carnets d'adresses
- Dossiers et messages de courrier
- Extensions et add-ons
- Signatures
- Préférences et configurations

### 💻 Utilisation

1. Téléchargez le script
2. Rendez-le exécutable : `chmod +x thunderbird-backup.sh`
3. Exécutez-le : `./thunderbird-backup.sh`
4. Vous serez invité à choisir un emplacement de sauvegarde
5. Le script créera à la fois un répertoire avec tous les fichiers et une archive compressée

### 🔄 Restauration

Pour restaurer à partir de la sauvegarde, utilisez simplement le script de restauration inclus dans le dossier de sauvegarde.

### ⚠️ Précautions

- Fermez Thunderbird avant d'exécuter le script pour une sauvegarde complète
- Conservez votre sauvegarde dans un endroit sûr
- Pour une protection complète, stockez cette sauvegarde sur un périphérique externe ou dans un stockage cloud

---

## English 🇬🇧

### 📋 Description

A comprehensive backup tool for Mozilla Thunderbird that exports all settings, accounts, messages, filters, passwords, signatures, and other configurations.

This bash script works on Linux, macOS, and Windows (via Git Bash or WSL) and creates a complete backup of your Thunderbird profile.

### ✨ Features

- Backup of multiple Thunderbird profiles
- Export of email accounts and their configurations
- Backup of messages (local and cached IMAP)
- Preservation of message filters and rules
- Export of passwords and login information
- Backup of signatures (all formats)
- Export of address books
- Backup of calendar data (if you use the Lightning extension)
- Preservation of extensions and add-ons
- Backup of preferences and customizations
- Intelligent profile detection
- Size estimation before backup
- Incremental backup option
- Included restoration script

### 📦 Backup Contents

- Profile folders (containing accounts, messages, filters, etc.)
- Password databases and saved logins
- Address books
- Mail folders and messages
- Extensions and add-ons
- Signatures
- Preferences and configurations

### 💻 Usage

1. Download the script
2. Make it executable: `chmod +x thunderbird-backup.sh`
3. Run it: `./thunderbird-backup.sh`
4. You will be prompted to choose a backup location
5. The script will create both a directory with all files and a compressed archive

### 🔄 Restoration

To restore from the backup, simply use the restoration script included in the backup folder.

### ⚠️ Precautions

- Close Thunderbird before running the script for a complete backup
- Keep your backup in a safe place
- For complete protection, store this backup on an external device or cloud storage

---

## License

Copyright © 2025 Antonin Nvh. Tous droits réservés / All rights reserved.

---

<div align="center">
<p>Made with ❤️ by <a href="https://codequantum.io">Antonin Nvh</a></p>
</div>