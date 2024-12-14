#!/bin/bash

#MASSE MASSE Paul-Basthylle
#22U2001

#j'utilise la logique du premier script amélioré, mais le code 
#c'est l'IA

# Liste de droits par groupe
declare -A GROUP_RIGHTS
GROUP_RIGHTS["cadres"]="Droit1 Droit2 Droit3 Droit4"
GROUP_RIGHTS["employes"]="Droit1 Droit2"
GROUP_RIGHTS["patrons"]="Droit1 Droit2 Droit3 Droit4 Droit5"
GROUP_RIGHTS["services"]="Droit1"

# Génère un mot de passe aléatoire de 16 caractères
generate_password() {
    local length=$1
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

# Fonction pour ajouter un utilisateur
# $1 : Nom de l'utilisateur, $2 : Rôle de l'utilisateur (cadre, employé, etc.), $3 : Durée du contrat en mois
add_user() {
    local USERNAME=$1
    local ROLE=$2
    local CONTRACT_DURATION=$3
    local EXPIRATION_DATE=$(date -d "+$CONTRACT_DURATION months" "+%Y-%m-%d")

    # Ajouter l'utilisateur à un groupe selon son rôle
    local GROUP
    if [ "$ROLE" == "cadre" ]; then
        GROUP="cadres"
    elif [ "$ROLE" == "employe" ]; then
        GROUP="employes"
    elif [ "$ROLE" == "patron" ]; then
        GROUP="patrons"
    else
        GROUP="services"
    fi

    # Créer le groupe s'il n'existe pas
    if ! getent group "$GROUP" > /dev/null; then
        sudo groupadd "$GROUP"
        echo "Groupe $GROUP créé."

        # Attribuer les droits au groupe
        assign_group_rights "$GROUP"
    fi

    # Création de l'utilisateur
    sudo useradd -m -G "$GROUP" "$USERNAME"
    local password=$(generate_password 16)
    echo "$USERNAME:$password" | sudo chpasswd
    echo "Utilisateur $USERNAME créé avec mot de passe $password et ajouté au groupe $GROUP."

    # Enregistrer l'expiration du contrat
    echo "$USERNAME $EXPIRATION_DATE" >> contract_expiration_dates.txt
    echo "Le contrat de $USERNAME expire le $EXPIRATION_DATE."
}

# Fonction pour assigner des droits à un groupe
assign_group_rights() {
    local GROUP=$1
    local RIGHTS=${GROUP_RIGHTS[$GROUP]}

    for RIGHT in $RIGHTS; do
        echo "%$GROUP ALL=(ALL) NOPASSWD: /usr/bin/$RIGHT" | sudo tee -a /etc/sudoers > /dev/null
        echo "Droit $RIGHT attribué au groupe $GROUP."
    done
}

# Fonction pour supprimer un utilisateur et retirer les accès liés
delete_user() {
    local USERNAME=$1
    sudo deluser "$USERNAME"
    echo "Utilisateur $USERNAME supprimé."
}

# Fonction pour vérifier les utilisateurs et leur expiration de contrat
check_expirations() {
    local current_date=$(date "+%Y-%m-%d")
    while IFS=" " read -r username expiration; do
        if [[ "$expiration" < "$current_date" ]]; then
            echo "Le contrat de $username a expiré. Suppression du compte..."
            delete_user "$username"
        fi
    done < contract_expiration_dates.txt
}

# Création d'un utilisateur
create_user() {
    local username=$1
    local fullname=$2
    local matricule=$3
    local role=$4  # Rôle ("cadre", "employe", "patron")
    local contract_duration=$5  # Durée du contrat en mois
    local password=$(generate_password 16)

    echo -e "\nCréation de l'utilisateur : $username, Nom complet : $fullname, Matricule : $matricule, Rôle : $role, Durée du contrat : $contract_duration mois"
    
    # Créer l'utilisateur
    sudo useradd -m -s /bin/bash -c "$fullname $matricule ($role)" "$username"
    if [ $? -eq 0 ]; then
        echo "Utilisateur '$username' créé avec succès."
        echo "$username:$password" | sudo chpasswd
        echo "Mot de passe défini pour '$username'."
        
        # Enregistrement dans un fichier de comptes utilisateurs
        echo "$username : $password" >> users_account.txt
        
        # Affectation des droits selon le rôle
        assign_rights "$username" "$role"
        
        # Ajout de la date d'expiration basée sur la durée du contrat
        local expiration_date
        expiration_date=$(date -d "+$contract_duration months" "+%Y-%m-%d")
        echo "$username $expiration_date" >> contract_expiration_dates.txt
        echo "Le contrat de $username expire le $expiration_date."
    else
        echo "Erreur lors de la création de l'utilisateur '$username'."
    fi
}

# Fonction pour vérifier si un utilisateur existe et tenter de se connecter

login_user() {
    local username=$1
    local entered_password=$2

    # Recherche si l'utilisateur existe dans le fichier des comptes
    if grep -w "$username" users_account.txt > /dev/null; then
        local stored_password
        stored_password=$(grep -w "$username" users_account.txt | cut -d: -f2)
        if [ "$entered_password" == "$stored_password" ]; then
            echo "Connexion réussie pour '$username'."
            return 0
        else
            echo "Mot de passe incorrect pour '$username'."
            return 1
        fi
    else
        echo "Utilisateur '$username' non trouvé."
        return 1
    fi
}

#Lecture dans le fichier des personnes recrutées

file1="fichier_recrutés.txt"

if [ -f "$file1" ]; then
    echo "Ouverture du fichier $file1 avec succès."
else
    echo "Erreur d'ouverture du fichier $file1 !" >> script_error.txt
    exit 1
fi

while IFS=" " read -r fullname matricule role contract_duration; do
    username=$(echo "$fullname" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')  # Création du nom d'utilisateur sans espaces et en minuscules
    create_user "$username" "$fullname" "$matricule" "$role" "$contract_duration"
done < "$file1"

# Vérifier les expirations des contrats
check_expirations

echo "Script terminé."

