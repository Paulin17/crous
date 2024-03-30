#Notification de démarrage du script
curl \
        -H "Title: Demarrage script" \
        -H "Tags: heavy_check_mark," \
        -d "En attente de repas" \
        ntfy.sh/debug_repas_crous; #envoie une notification de démarrage

url=https://crousandgo.crous-poitiers.fr/larochelle/categorie-produit/sites-la-rochelle/ #URL Crous

debut(){ #Ici on reinitialise tout les variables
    echo "Début script"
    rm -R tmp/ 2>/dev/null
    echo "0" > pause
    nb_repas=0
    nbrepas_tmp=0
    unset jl
    unset jl_ok
    unset jl_notif
    unset jl_notifier
    declare -a jl
    declare -a jl_ok
    declare -a jl_notif
    declare -a jl_notifier
}

download_index(){ #Met dans $code_html le code de la page principale 
    code_html=$(curl -s "$url")
}

get_link(){ #Détecte si des repas sont en ligne, renvoie $nb_repas disponible + liste des lien dispo

    #Extraction des url des repas.
    #              affiche le code   Récupere les href        cherche la chaine         cut le href    enleve les doublons
    repas_links=$(echo $code_html | grep -oE 'href="([^"#]+)"'|grep 'repas-la-rochelle'| cut -d'"' -f2|uniq)
  
    #Compte les espaces
    nb_repas=$(expr $(echo $repas_links|grep -o ' ' | wc -l) + 1 )
}

get_jour(){ #Nécessite la liste des repas, renvoie la liste des jour qui sont dispo ($jl) et stoke les page dans tpm/
    jl=''
    jl_type=''
    rm -R tmp/ 2>/dev/null
    mkdir tmp/
    for link in $repas_links; do
        code_temp=$(curl -sL "$link") #Telecharge la page
        traitement_temp=$(echo $code_temp |grep -oP '<h1.*?>(.*?)<\/h1>' | sed -e 's/<[^>]*>//g'|tr ' ' '_') #Récupere uniquement le contenue de H1 en remplacant par des tiret du bas les espaces
        jour=$(echo $traitement_temp |cut -d '_' -f 5) #Récupere le jour de la semaine

        #Si le prétraitement contient 'végétarien', on le specifie sinon c'st un repas normal.
        if grep -q "végétarien"<<< $traitement_temp ;then #cette ligne génére un echo
            type='Végétarien'
        else
            type='Normal'
        fi
        echo "$jour-$type"
        jl_type+=("$jour-$type") #Complemente la variable Jl(jours liste) avec les info du repas qui vient d'être traité
        echo $code_temp > "tmp/$traitement_temp.html"
    done

}

check_forms(){ #Vérifie si le formulaire est valide (2 option pour chaque select). $jl_ok avec les jours commandable
    i=1
    unset jl_ok
    declare -a jl_ok
    for fichier in tmp/*; do #Pour chaque fichier dans tmp
        #on initialise les jour ok
        jour_actuel=${jl_type[$(($i))]}
        nb_form_ok=$(cat $fichier | grep -no '<select.*<option.*</option>.*<option.*</option>.*</select>'| sed 's/<\/select>/\~/g'|grep -o '~'|wc -w)
        if  [ "$nb_form_ok" -eq "6" ]; then
             echo "$jour_actuel - Formulaire OK : $nb_form_ok"
             jl_ok+=("$jour_actuel")
        else
            echo "$jour_actuel - Formulaire incorect : $nb_form_ok"
        fi
        i=$(($i+1))
    done
    echo "liste des jour:${jl_ok[@]}"
}

notif(){ #Prend un parametre un nombre de repas et un tableau contenant les jour
    var=""
    for i in "${@:2}"; do
        var+=$i/
    done
    echo $var
    curl \
    -H "Title: "$1" Nouveau repas Disponibles" \
    -H "Tags: warning," \
    -d "$var" \
    ntfy.sh/repas_crous #envoie une requette de notification
}

wait_samedi(){ #Attend le prochain samedi a 00h01
    next_saturday=$(date -d 'next Saturday 00:01' +'%s')
    current_time=$(date +'%s')
    time_to_wait=$((next_saturday - current_time))
    curl -H "Title: Attente jusqu'au prochain Samedi" -d "temp: $time_to_wait" ntfy.sh/debug_repas_crous; 2>/dev/null #envoie une notification de démarrage
    echo "Attente jusqu'au prochain samedi à 00h01, temp: $time_to_wait"
    sleep $time_to_wait
    curl -H "Title: Redémarage Script" -d "En attente de repas" ntfy.sh/debug_repas_crous; 2>/dev/null #envoie une notification de démarrage
}

#Début du programme principal

while true ; do
    debut
    while true ; do #tant que nb_repas est strictement inférieur a 2
        date '+%Y-%m-%d %H:%M:%S'
        download_index
        get_link
        if [ "$nb_repas" -gt 1 ]; then
            break
        fi
        echo "Aucun repas disponible prochaine tentative dans 60s"
        sleep 60
    done
    echo "$nb_repas repas disponibles"
    nb_repas=-1
    while [ "$nb_repas" -lt 10 ]; do #Tant que le nombre de repas est inférieur a 10
        #Affiche la date, télécharge le code, recupere les lien, en déduit les jour, et vérifie les forms 
        date '+%Y-%m-%d %H:%M:%S'
        download_index
        get_link
        echo "Dowload+get_link fait"
        get_jour
        echo
        check_forms
        echo "Jour vérifié"

        if [ "$nbrepas_tmp" -lt "$nb_repas" ];then #Si y a de nouveau repas,
        unset jl_notif
        declare -a jl_notif
        for k in ${jl_ok[@]};do #pr i parcourant tout les élément de jl_ok
            if grep -q "$k" <<< "${jl_notifier[*]}";then #si il sont déja ds les jours notifié
                : #ne rien faire
            else
                jl_notif+=("$k") #sinon l'a
            fi
        done
        notif $(("$nb_repas"-"$nbrepas_tmp")) "${jl_notif[@]}"
        nbrepas_tmp=$nb_repas
        jl_notifier=("${jl_ok[@]}")

        fi #Si le nb de repas >9 aou que le contenue de pause est 1 on arrette le 
        if [ "$nb_repas" -gt 9 ] || [ "$(cat pause)" -eq 1 ]; then
            break
        fi
        echo "En attente de nouveau repas, prochaine tentative dans 60s"
        sleep 3
    done
    wait_samedi
done