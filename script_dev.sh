#!/bin/bash

#Notification de démarrage du script
echo $(date '+%y-%m-%d %H:%M:%S')' WARNING Démarrage, envoi de la première notification'

curl \
        -H "Title: Demarrage script" \
        -H "Tags: heavy_check_mark," \
        -d "En attente de repas" \
        ntfy.sh/dev_repas_crous 1> /dev/null 2>/dev/null #envoie une notification de démarrage

url=https://crousandgo.crous-poitiers.fr/larochelle/categorie-produit/sites-la-rochelle/ #URL Crous

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
    rm -R tmp/ 2>/dev/null
    mkdir tmp/
    echo "0" > pause
    nb_repas=0
    nbrepas_tmp=0
    unset dico_jour
    declare -g -A dico_jour
}

download_index(){ #Telecharge la page principale de vente et la met dans $code_html
    code_html=$(curl -s "$url")
    echo $(date '+%y-%m-%d %H:%M:%S')" NOTICE Téléchargement de l'accueil (index)"
}

download_secondaires(){
    #Extraction des url des repas:
    #              affiche le code   Récupere les href        cherche la chaine \/       cut le href    enleve les doublons
    repas_links=$(echo $code_html | grep -oE 'href="([^"#]+)"'|grep 'repas-la-rochelle'| cut -d'"' -f2|uniq)
    
    #Telecharge les pages des repas
    for link in $repas_links; do
        code_temp=$(curl -s "$link") #Telecharge la page

        traitement_temp=$(echo $code_temp |grep -oP '<h1.*?>(.*?)<\/h1>' | sed -e 's/<[^>]*>//g'|tr ' ' '_') #Récupere uniquement le contenue de H1 en remplacant les espaces par des tirret du bas.
        if [[ -v dico_jour["$traitement_temp"] ]]; then
            :
        else
            jour=$(echo $traitement_temp | cut -d '_' -f 5 | sed 's/^./\U&/')
            date=$(echo $traitement_temp |cut -d '_' -f 6)
            mois=$(echo $traitement_temp |cut -d '_' -f 7)
            year=$(echo $traitement_temp |cut -d '_' -f 8)

            current_date=$(date +%d-%m-%Y)

            if [[ "$current_date" < "$year-${asso_mois[$mois]}-$date" ]]; then
                #La date n'est pas encore passé

                if grep -q "végétarien"<<< $1 ;then 
                    type='Végétarien'
                else
                    type='Normal'
                fi

                dico_jour["$traitement_temp"]=$(echo "$jour $date $mois $year-$type"|tr ' ' '_') #Enregistre l'entré dans un dictionaire
                echo $code_temp > "tmp/$traitement_temp.html" #Enregistre dans le fichier
            else
                #La date est déjà passé on s'en fou
                pass
            fi
        fi
        echo $(date '+%y-%m-%d %H:%M:%S')" DEBUG Telechargement de "$traitement_temp
    done
}


send_notif(){ #Prend un parametre un nombre de repas et un tableau contenant les jour et envoie une notification
    var=""
    for jour in "${@:2}"; do
        var+="$jour\n"
    done
    curl \
    -H "Title: "$1" Nouveau repas Disponibles" \
    -H "Tags: warning," \
    -d "$(echo -e "$var"|tr '_' ' ')" \
    ntfy.sh/dev_repas_crous 1> /dev/null 2>/dev/null #envoie une requette de notification
}

wait_samedi(){ #Attend le prochain samedi a 00h01
    next_saturday=$(date -d 'next Saturday 12:01' +'%s')
    current_time=$(date +'%s')
    time_to_wait=$((next_saturday - current_time))
    curl -H "Title: Attente jusqu'au prochain Samedi" -d "temp: $time_to_wait" ntfy.sh/dev_repas_crous 1> /dev/null 2>/dev/null #envoie une notification de démarrage
    echo $(date '+%y-%m-%d %H:%M:%S')" WARNING  Attente jusqu'au prochain samedi a 12h01, temp: $time_to_wait"
    sleep $time_to_wait
    curl -H "Title: Redémarage Script" -d "En attente de repas" ntfy.sh/dev_repas_crous 1> /dev/null 2>/dev/null #envoie une notification de démarrage
}

reset
while true ; do
    download_index
    download_secondaires

    unset notif
    declare -a notif

    for jour in "${!dico_jour[@]}"; do
        valeur="${dico_jour[$jour]}"
        if [[ "$valeur" != *@done ]]; then
            notif+=("$valeur")
            dico_jour[$jour]="${valeur}@done"
        fi
    done

    if [[ ${#notif[@]} -ne 0 ]]; then
        send_notif ${#notif[@]} ${notif[@]}
    fi
    
    if [ "$nb_repas" -gt 9 ] || [ "$(cat pause)" -eq 1 ]; then
        wait_samedi
    else
        echo $(date '+%y-%m-%d %H:%M:%S')" NOTICE En attente de nouveau repas, prochaine tentative dans 60s"
        sleep 1
    fi
done