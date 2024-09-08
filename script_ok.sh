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
    unset jl_ok
    unset jl_notif
    unset jl_notifier
    declare -g -A dico_jour
    declare -a jl_ok
    declare -a jl_notif
    declare -a jl_notifier
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
        
        jour=$(echo "$input" | cut -d '_' -f 5 | sed 's/^./\U&/')
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


        echo $(date '+%y-%m-%d %H:%M:%S')" DEBUG Telechargement de "$traitement_temp
    done

    #Compte les repas disponibles
    nb_repas=$(find tmp/ -maxdepth 1 -type f | wc -l)
}


check_forms(){ #Vérifie si le formulaire est valide (2 option pour chaque select). $jl_ok avec les jours commandable
    i=1
    #on (ré)initialise les jour ok
    jl_ok=("")
    for fichier in tmp/* ; do #Pour chaque fichier dans tmp

        #Renvoie le nombre de select avec au moin 2 options
        #nb_form_ok=$(cat $fichier | grep -no '<select.*<option.*</option>.*<option.*</option>.*</select>'| sed 's/<\/select>/\~/g'|grep -o '~'|wc -w )
        cat $fichier | grep -o '<option value="0">18:30-20:30</option>'
        sleep 1
        if  [ "$nb_form_ok" -eq "6" ]; then
             echo $(date '+%y-%m-%d %H:%M:%S')" DEBUG $jour_actuel - Formulaire OK : $nb_form_ok"
             jl_ok+=("$jour_actuel")
        else
            echo $(date '+%y-%m-%d %H:%M:%S')" DEBUG $jour_actuel - Formulaire incorect : $nb_form_ok"
        fi
    done
    echo $(date '+%y-%m-%d %H:%M:%S')" INFO Liste des jours disponibles : ${jl_ok[@]}"
}

notif(){ #Prend un parametre un nombre de repas et un tableau contenant les jour et envoie une notification
    var=""
    for i in "${@:2}"; do
        var+="$i"
    done
    echo "$(echo -e "$var")"
    curl \
    -H "Title: "$1" Nouveau repas Disponibles" \
    -H "Tags: warning," \
    -d "$(echo -e "$var")" \
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
    echo "Clés : ${!dico_jour[@]}"
    echo "Valeurs : ${dico_jour[@]}"

    #Affiche la date, télécharge le code, recupere les lien, en déduit les jour, et vérifie les forms 
    check_forms
    if [ "$nbrepas_tmp" -lt "$nb_repas" ];then #Si y a de nouveau repas,

        unset jl_notif      #Reset les repas 
        declare -a jl_notif #à envoyé en notif

        for k in ${jl_ok[@]};do #pour k parcourant tout les élément de jl_ok
            if grep -q "$k" <<< "${jl_notifier[*]}";then #si il sont déja ds les jours notifié
                : #ne rien faire
            else
                jl_notif+=("$k") #sinon l'ajouter au truc qui partent en notif
            fi
        done
        echo $(date '+%y-%m-%d %H:%M:%S')' INFO Préparation notif : nb-repas '$(("$nb_repas"-"$nbrepas_tmp"))
        echo $(date '+%y-%m-%d %H:%M:%S')' INFO |-> repas : '"${jl_notif[@]}"
        notif $(("$nb_repas"-"$nbrepas_tmp")) "${jl_notif[@]}"
        echo $(date '+%y-%m-%d %H:%M:%S')' NOTICE Notification envoyée !'
        nbrepas_tmp=$nb_repas
        jl_notifier=("${jl_ok[@]}")
    fi
    if [ "$nb_repas" -gt 9 ] || [ "$(cat pause)" -eq 1 ]; then
        wait_samedi
    else
        echo $(date '+%y-%m-%d %H:%M:%S')" NOTICE En attente de nouveau repas, prochaine tentative dans 60s"
        sleep 60
    fi
done