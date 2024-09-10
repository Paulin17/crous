#!/bin/bash

#Notification de démarrage du script
echo $(date '+%y-%m-%d %H:%M:%S')' WARNING Démarrage, envoi de la première notification'

curl \
        -H "Title: Demarrage script" \
        -H "Tags: heavy_check_mark," \
        -d "En attente de repas" \
        ntfy.sh/debug_repas_crous 1> /dev/null 2>/dev/null #envoie une notification de démarrage

url_index=https://crousandgo.crous-poitiers.fr/larochelle/categorie-produit/sites-la-rochelle/ #URL Crous

declare -rA asso_mois=(
    ['Janvier']='01'
    ['Février']='02'
    ['Mars']='03'
    ['Avril']='04'
    ['Mai']='05'
    ['Juin']='06'
    ['Juillet']='07'
    ['Août']='08'
    ['Septembre']='09'
    ['Octobre']='10'
    ['Novembre']='11'
    ['Décembre']='12'
)

#Reinitialisation de toutes les variables
reset(){ 
    echo $(date '+%y-%m-%d %H:%M:%S')" WARNING Reset script (variables,folder,pause)"
    echo "0" > pause
    unset dico_jour
    unset order_dico_jour
    declare -g -A dico_jour
    declare -g -a order_dico_jour
}

send_notif(){ #Prend un parametre un tableau contenant les jours et envoie une notification
    var=""
    for jour in "${@}"; do
        var+="$jour\n"
    done
    curl \
    -H "Title: "$#" Nouveau repas Disponibles" \
    -H "Tags: warning," \
    -d "$(echo -e "$var"|tr '_' ' ')" \
    ntfy.sh/repas_crous 1> /dev/null 2>/dev/null #envoie une requette de notification
}

wait_samedi(){ #Attend le prochain samedi a 00h01
    next_saturday=$(date -d 'next Saturday 12:01' +'%s')
    current_time=$(date +'%s')
    time_to_wait=$((next_saturday - current_time))
    curl -H "Title: Attente jusqu'au prochain Samedi" -d "Temp: $time_to_wait" ntfy.sh/debug_repas_crous 1> /dev/null 2>/dev/null #envoie une notification de démarrage
    echo $(date '+%y-%m-%d %H:%M:%S')" WARNING  Attente jusqu'au prochain samedi a 12h01, temp: $time_to_wait"
    sleep $time_to_wait
    curl -H "Title: Redémarage Script" -d "En attente de repas" ntfy.sh/debug_repas_crous 1> /dev/null 2>/dev/null #envoie une notification de démarrage
}

reset
while true ; do
    #Telecharge la page principale de vente et la met dans $code_html
    code_html=$(curl -s "$url_index")
    echo $(date '+%y-%m-%d %H:%M:%S')" NOTICE Téléchargement de l'accueil (index)"

    #Extraction des url des repas:
    #              affiche le code   Récupere les href        cherche la chaine \/       cut le href    enleve les doublons
    repas_links=$(echo $code_html | grep -oE 'href="([^"#]+)"'|grep 'repas-la-rochelle'| cut -d'"' -f2|uniq)
    
    #Telecharge les pages des repas
    for link in $repas_links; do
        code_temp=$(curl -s "$link") #Telecharge la page du repas

        #Récupere uniquement le contenue de H1 en remplacant les espaces par des tirret du bas.
        traitement_temp=$(echo $code_temp |grep -oP '<h1.*?>(.*?)<\/h1>' | sed -e 's/<[^>]*>//g'|tr ' ' '_')
        echo $(date '+%y-%m-%d %H:%M:%S')" DEBUG Telechargement de "$traitement_temp

        if [[ -v dico_jour["$traitement_temp"] ]]; then
            : #Si le jour est déjà present dans le dictionaire, alors on ne fait rien.
        else
            #Récuperation des information spécifique du repas
            jour=$(echo $traitement_temp | cut -d '_' -f 5 | sed 's/^./\U&/')
            date=$(echo $traitement_temp |cut -d '_' -f 6)
            mois=$(echo $traitement_temp |cut -d '_' -f 7)
            year=$(echo $traitement_temp |cut -d '_' -f 8)
        
            current_date=$(date +%d-%m-%Y)
            #On vérifie si le repas n'est pas dans le passé...
            if [[ "$current_date" < "$date-${asso_mois[$mois]}-$year" ]]; then
                #La date n'est pas encore passé

                type=$(grep -q "végétarien" <<< $traitement_temp && echo 'Végétarien' || echo 'Normal')

                dico_jour["$traitement_temp"]=$(echo "$jour $date $mois $year $type"|tr ' ' '_') #Enregistre l'entré dans un dictionaire
                order_dico_jour+=("$traitement_temp")
            fi
        fi
        
    done
    
    unset notif
    declare -a notif

    for jour in "${order_dico_jour[@]}"; do
        valeur="${dico_jour[$jour]}"
        if [[ "$valeur" != *@done ]]; then
            notif+=("$valeur")
            dico_jour[$jour]="${valeur}@done"
        fi
    done

    if [[ ${#notif[@]} -ne 0 ]]; then
        echo $(date '+%y-%m-%d %H:%M:%S')' INFO Préparation notif : nb-repas '${#notif[@]}
        echo $(date '+%y-%m-%d %H:%M:%S')' INFO |-> repas : '"${notif[@]}"
        send_notif ${notif[@]}
        echo $(date '+%y-%m-%d %H:%M:%S')' NOTICE Notification envoyée !'
        
    fi
    
    if [ ${#dico_jour[@]} -gt 9 ] || [ "$(cat pause)" -eq 1 ]; then
        wait_samedi
        reset
    else
        echo $(date '+%y-%m-%d %H:%M:%S')" NOTICE En attente de nouveau repas, prochaine tentative dans 60s"
        sleep 60
    fi
done