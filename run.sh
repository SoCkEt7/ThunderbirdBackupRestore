#!/bin/sh
# Script de sauvegarde des paramètres Thunderbird
# Par Antonin Nvh - https://codequantum.io
# Sauvegarde uniquement les paramètres, pas les emails

# Couleurs basiques
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Afficher l'en-tête
echo "${BLUE}===============================================${NC}"
echo "${BLUE}   OUTIL DE SAUVEGARDE PARAMÈTRES THUNDERBIRD  ${NC}"
echo "${BLUE}===============================================${NC}"

# Vérifier les commandes requises
echo "${YELLOW}Vérification des utilitaires...${NC}"
for cmd in grep tar find; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
        echo "${YELLOW}Avertissement: Commande '$cmd' non installée.${NC}"
    fi
done

# Détection de l'OS
if [ -f /etc/os-release ]; then
    # Linux
    OS="linux"
    PROFILE_DIR="$HOME/.thunderbird"
elif [ "$(uname)" = "Darwin" ]; then
    # macOS
    OS="mac"
    PROFILE_DIR="$HOME/Library/Thunderbird"
elif [ -d "$APPDATA/Thunderbird" ]; then
    # Windows
    OS="windows"
    PROFILE_DIR="$APPDATA/Thunderbird"
else
    OS="unknown"
    PROFILE_DIR=""
fi

echo "${GREEN}Système d'exploitation détecté: ${OS}${NC}"

# Vérifier si le répertoire des profils existe
if [ ! -d "$PROFILE_DIR" ]; then
    echo "${YELLOW}Répertoire principal non trouvé: ${PROFILE_DIR}${NC}"
    
    # Chemins alternatifs
    if [ "$OS" = "linux" ] && [ -d "$HOME/.var/app/org.mozilla.Thunderbird/data/thunderbird" ]; then
        PROFILE_DIR="$HOME/.var/app/org.mozilla.Thunderbird/data/thunderbird"
    elif [ "$OS" = "linux" ] && [ -d "$HOME/snap/thunderbird/common/.thunderbird" ]; then
        PROFILE_DIR="$HOME/snap/thunderbird/common/.thunderbird"
    elif [ "$OS" = "mac" ] && [ -d "$HOME/Library/Application Support/Thunderbird" ]; then
        PROFILE_DIR="$HOME/Library/Application Support/Thunderbird"
    elif [ "$OS" = "windows" ] && [ -d "$APPDATA/Mozilla/Thunderbird" ]; then
        PROFILE_DIR="$APPDATA/Mozilla/Thunderbird"
    fi
    
    if [ -d "$PROFILE_DIR" ]; then
        echo "${GREEN}Répertoire de profil Thunderbird trouvé: ${PROFILE_DIR}${NC}"
    else
        echo "${RED}Impossible de trouver le répertoire de profil Thunderbird.${NC}"
        echo "${YELLOW}Veuillez entrer le chemin complet:${NC}"
        read -r PROFILE_DIR
        
        if [ ! -d "$PROFILE_DIR" ]; then
            echo "${RED}Chemin invalide. Abandon.${NC}"
            exit 1
        fi
    fi
fi

# Vérifier si Thunderbird est en cours d'exécution
thunderbird_running=0
if [ "$OS" = "linux" ] && pgrep -x "thunderbird" > /dev/null 2>&1; then
    thunderbird_running=1
elif [ "$OS" = "mac" ] && (pgrep -x "thunderbird" > /dev/null 2>&1 || pgrep -x "Thunderbird" > /dev/null 2>&1); then
    thunderbird_running=1
elif [ "$OS" = "windows" ] && tasklist 2>/dev/null | grep -i "thunderbird.exe" > /dev/null; then
    thunderbird_running=1
fi

if [ $thunderbird_running -eq 1 ]; then
    echo "${YELLOW}Thunderbird semble être en cours d'exécution.${NC}"
    echo "${YELLOW}Pour une sauvegarde complète, fermez Thunderbird d'abord.${NC}"
    echo "${YELLOW}Continuer quand même? (o/n)${NC}"
    read -r choice
    if [ "$choice" != "o" ] && [ "$choice" != "O" ]; then
        echo "${RED}Sauvegarde annulée.${NC}"
        exit 0
    fi
fi

# Définir le répertoire de sauvegarde
echo "${YELLOW}Où souhaitez-vous sauvegarder?${NC}"
echo "Entrez le chemin (défaut: répertoire courant):"
read -r BACKUP_PATH

# Si aucune entrée, utiliser le répertoire courant
if [ -z "$BACKUP_PATH" ]; then
    BACKUP_PATH="$(pwd)"
fi

# Date actuelle pour le nom de la sauvegarde
CURRENT_DATE=$(date +"%Y-%m-%d")
BACKUP_NAME="thunderbird_settings_${CURRENT_DATE}"
BACKUP_DIR="${BACKUP_PATH}/${BACKUP_NAME}"

# Créer le répertoire de sauvegarde
mkdir -p "$BACKUP_DIR"
if [ ! -d "$BACKUP_DIR" ]; then
    echo "${RED}Erreur: Impossible de créer le répertoire de sauvegarde.${NC}"
    exit 1
fi

echo "${GREEN}Sauvegarde sera créée dans: ${BACKUP_DIR}${NC}"

# Fonction pour sauvegarder un profil
backup_profile() {
    profile_path="$1"
    profile_name="$2"
    backup_path="${BACKUP_DIR}/profiles/${profile_name}"
    
    echo "${BLUE}Sauvegarde du profil: ${profile_name}${NC}"
    
    # Créer le répertoire de sauvegarde du profil
    mkdir -p "$backup_path"
    
    # Éléments importants à sauvegarder (sans les emails)
    echo "${GREEN}Copie des paramètres de base...${NC}"
    for item in prefs.js user.js persdict.dat hostperm.1 permissions.sqlite handlers.json mimeTypes.rdf compatability.ini; do
        if [ -e "${profile_path}/${item}" ]; then
            cp -f "${profile_path}/${item}" "${backup_path}/" 2>/dev/null
        fi
    done
    
    echo "${GREEN}Copie des informations de sécurité...${NC}"
    for item in cert9.db cert8.db key4.db key3.db logins.json signons.sqlite pkcs11.txt; do
        if [ -e "${profile_path}/${item}" ]; then
            cp -f "${profile_path}/${item}" "${backup_path}/" 2>/dev/null
        fi
    done
    
    echo "${GREEN}Copie des filtres et règles...${NC}"
    for item in filters.dat msgFilterRules.dat training.dat virtualFolders.dat; do
        if [ -e "${profile_path}/${item}" ]; then
            cp -f "${profile_path}/${item}" "${backup_path}/" 2>/dev/null
        fi
    done
    
    echo "${GREEN}Copie des carnets d'adresses...${NC}"
    for item in abook.mab abook-1.mab history.mab personaladdressbook.mab; do
        if [ -e "${profile_path}/${item}" ]; then
            cp -f "${profile_path}/${item}" "${backup_path}/" 2>/dev/null
        fi
    done
    
    # Copier le répertoire d'adresses si présent
    if [ -d "${profile_path}/addressBook" ]; then
        cp -rf "${profile_path}/addressBook" "${backup_path}/" 2>/dev/null
    fi
    
    echo "${GREEN}Copie des extensions...${NC}"
    for item in extensions extensions.json extensions.ini extensions.sqlite extension-preferences.json; do
        if [ -e "${profile_path}/${item}" ]; then
            cp -rf "${profile_path}/${item}" "${backup_path}/" 2>/dev/null
        fi
    done
    
    # Copier l'UI personnalisée
    if [ -d "${profile_path}/chrome" ]; then
        cp -rf "${profile_path}/chrome" "${backup_path}/" 2>/dev/null
    fi
    
    # Copier les données de calendrier
    if [ -d "${profile_path}/calendar-data" ]; then
        cp -rf "${profile_path}/calendar-data" "${backup_path}/" 2>/dev/null
    fi
    if [ -e "${profile_path}/calendar.sqlite" ]; then
        cp -f "${profile_path}/calendar.sqlite" "${backup_path}/" 2>/dev/null
    fi
    
    echo "${GREEN}Copie des signatures...${NC}"
    # Copier les signatures
    for item in signatures signatureSwitch stationery Templates; do
        if [ -d "${profile_path}/${item}" ]; then
            cp -rf "${profile_path}/${item}" "${backup_path}/" 2>/dev/null
        fi
    done
    
    # Rechercher et copier les configurations de compte
    echo "${GREEN}Recherche des configurations de compte...${NC}"
    find "${profile_path}" -name "account*.json" -o -name "accounts.rdf" -o -name "mailViews.dat" | while read -r file; do
        if [ -f "$file" ]; then
            rel_path=$(echo "$file" | sed "s|${profile_path}/||")
            target_dir=$(dirname "${backup_path}/account-configs/${rel_path}")
            mkdir -p "$target_dir"
            cp -f "$file" "${backup_path}/account-configs/${rel_path}" 2>/dev/null
        fi
    done
    
    # Rechercher et copier les signatures supplémentaires
    echo "${GREEN}Recherche de signatures supplémentaires...${NC}"
    find "${profile_path}" -name "*.sig" -o -name "*signature*.html" -o -name "*signature*.txt" | while read -r file; do
        if [ -f "$file" ]; then
            mkdir -p "${backup_path}/additional_signatures"
            cp -f "$file" "${backup_path}/additional_signatures/" 2>/dev/null
        fi
    done
    
    echo "${GREEN}✓ Profil ${profile_name} sauvegardé avec succès${NC}"
}

# Rechercher et sauvegarder tous les profils
echo "${BLUE}Recherche des profils Thunderbird...${NC}"

# Créer le répertoire de sauvegarde des profils
mkdir -p "${BACKUP_DIR}/profiles"

# Analyser profiles.ini
PROFILES_INI="${PROFILE_DIR}/profiles.ini"
if [ -f "$PROFILES_INI" ]; then
    echo "${GREEN}Fichier profiles.ini trouvé${NC}"
    
    # Copier profiles.ini
    cp -f "$PROFILES_INI" "${BACKUP_DIR}/"
    
    # Extraire les profils
    profile_sections=$(grep "^\[Profile" "$PROFILES_INI")
    profile_count=0
    
    # Traiter chaque profil
    echo "$profile_sections" | while read -r line; do
        profile_num=$(echo "$line" | sed 's/\[Profile\(.*\)\]/\1/')
        
        # Obtenir le chemin du profil
        is_relative=$(grep -A 10 "^\[Profile${profile_num}\]" "$PROFILES_INI" | grep "^IsRelative=" | cut -d"=" -f2 | tr -d '\r')
        path_value=$(grep -A 10 "^\[Profile${profile_num}\]" "$PROFILES_INI" | grep "^Path=" | cut -d"=" -f2 | tr -d '\r')
        
        # Obtenir le nom du profil
        profile_name=$(grep -A 10 "^\[Profile${profile_num}\]" "$PROFILES_INI" | grep "^Name=" | cut -d"=" -f2 | tr -d '\r')
        if [ -z "$profile_name" ]; then
            profile_name="Profile${profile_num}"
        fi
        
        # Déterminer le chemin réel du profil
        profile_path=""
        if [ "$is_relative" = "1" ]; then
            profile_path="${PROFILE_DIR}/${path_value}"
        else
            profile_path="$path_value"
        fi
        
        # Vérifier si le profil existe
        if [ -d "$profile_path" ]; then
            echo "${GREEN}Profil trouvé: ${profile_name} à ${profile_path}${NC}"
            backup_profile "$profile_path" "$profile_name"
            profile_count=$((profile_count + 1))
        else
            echo "${YELLOW}Avertissement: Répertoire de profil non trouvé: ${profile_path}${NC}"
        fi
    done
    
    if [ $profile_count -eq 0 ]; then
        echo "${YELLOW}Avertissement: Aucun profil trouvé dans profiles.ini${NC}"
        
        # Chercher le profil par défaut
        default_profile=$(find "$PROFILE_DIR" -name "*.default" -type d | head -n 1)
        if [ -n "$default_profile" ]; then
            echo "${GREEN}Profil par défaut trouvé à ${default_profile}${NC}"
            backup_profile "$default_profile" "default"
        else
            echo "${RED}Erreur: Impossible de trouver des profils Thunderbird${NC}"
        fi
    fi
else
    echo "${YELLOW}Avertissement: profiles.ini non trouvé à ${PROFILES_INI}${NC}"
    echo "${YELLOW}Recherche du répertoire de profil par défaut...${NC}"
    
    # Essayer de trouver le répertoire de profil par défaut
    default_profile=$(find "$PROFILE_DIR" -name "*.default" -type d | head -n 1)
    if [ -n "$default_profile" ]; then
        echo "${GREEN}Profil par défaut trouvé à ${default_profile}${NC}"
        backup_profile "$default_profile" "default"
    else
        echo "${RED}Erreur: Impossible de trouver des profils Thunderbird${NC}"
        exit 1
    fi
fi

# Créer un fichier de métadonnées avec des informations de sauvegarde
echo "${BLUE}Création des métadonnées de sauvegarde...${NC}"
cat > "${BACKUP_DIR}/info-sauvegarde.txt" << EOF
Informations sur la sauvegarde des paramètres Thunderbird
========================================================
Date: $(date)
Système: $OS
Répertoire de profil Thunderbird: $PROFILE_DIR

Cette sauvegarde contient:
- Configurations des comptes
- Filtres et règles de messagerie
- Mots de passe et identifiants enregistrés
- Signatures et modèles
- Carnets d'adresses
- Extensions et préférences

NOTE: Cette sauvegarde N'INCLUT PAS les messages emails.

Pour restaurer:
1. Fermez Thunderbird s'il est en cours d'exécution
2. Remplacez le contenu de votre répertoire de profil Thunderbird par les fichiers de sauvegarde
3. Redémarrez Thunderbird
EOF

# Créer une archive de la sauvegarde
echo "${BLUE}Création de l'archive de sauvegarde...${NC}"
current_dir=$(pwd)
cd "$BACKUP_PATH" || exit 1
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
cd "$current_dir" || exit 1

# Vérifier l'archive de sauvegarde
if [ -f "${BACKUP_PATH}/${BACKUP_NAME}.tar.gz" ]; then
    echo "${GREEN}✓ Archive de sauvegarde créée avec succès: ${BACKUP_PATH}/${BACKUP_NAME}.tar.gz${NC}"
    echo "${GREEN}  Les fichiers de sauvegarde sont également disponibles à: ${BACKUP_DIR}${NC}"
else
    echo "${RED}Échec de la création de l'archive de sauvegarde${NC}"
    echo "${YELLOW}Vos fichiers de sauvegarde sont toujours disponibles à: ${BACKUP_DIR}${NC}"
fi

echo "${BLUE}===============================================${NC}"
echo "${GREEN}Sauvegarde des paramètres Thunderbird terminée!${NC}"
echo "${BLUE}===============================================${NC}"
echo "${YELLOW}Notes:${NC}"
echo "1. La sauvegarde inclut les profils, paramètres, mais PAS les messages"
echo "2. Pour restaurer, utilisez les fichiers de sauvegarde pour remplacer votre profil"
echo "3. Conservez cette sauvegarde dans un endroit sûr"
echo "4. Pour une protection complète, stockez cette sauvegarde sur un périphérique externe"

exit 0
