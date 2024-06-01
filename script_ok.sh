#Notification de démarrage du script
echo $(date '+%y-%m-%d %H:%M:%S')' WARNING Démarrage, envoi de la première notification'
curl \
        -H "Title: Demarrage script" \
        -H "Tags: heavy_check_mark," \
        -d "En attente de repas" \
        ntfy.sh/debug_repas_crous 1> /dev/null 2>/dev/null #envoie une notification de démarrage

url=https://crousandgo.crous-poitiers.fr/larochelle/categorie-produit/sites-la-rochelle/ #URL Crous

#Reinitialisation de toutes les variables
reset(){ 
    echo $(date '+%y-%m-%d %H:%M:%S')" WARNING Reset script (variables,folder,pause)"
    rm -R tmp/ 2>/dev/null
    mkdir tmp/
    echo "0" > pause
    nb_repas=0
    nbrepas_tmp=0
    unset jl
    unset jl_ok
    unset jl_type
    unset jl_notif
    unset jl_notifier
    declare -a jl
    declare -a jl_ok
    declare -a jl_type
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
    
    #Telecharge les pasge des repas
    for link in $repas_links; do
        code_temp=$(curl -sL "$link") #Telecharge la page
        traitement_temp=$(echo $code_temp |grep -oP '<h1.*?>(.*?)<\/h1>' | sed -e 's/<[^>]*>//g'|tr ' ' '_') #Récupere uniquement le contenue de H1 en remplacant les espaces par des tirret du bas.
        echo $code_temp > "tmp/$traitement_temp.html" #Enregistre dans le fichier
        echo $(date '+%y-%m-%d %H:%M:%S')" DEBUG Telechargement de "$traitement_temp
    done

    #Compte les repas disponibles
    nb_repas=$(find tmp/ -maxdepth 1 -type f | wc -l)
}

get_jour(){

    #Récupere le jour de la semaine
    jour=$(echo $1 |cut -d '_' -f 5) 
    
    #Si le prétraitement contient 'végétarien', on le specifie sinon c'st un repas normal.
    if grep -q "végétarien"<<< $1 ;then #cette ligne génére un echo
        type='Végétarien'
    else
        type='Normal'
    fi

    #Renvoie l'association jour-type
    echo "$jour-$type"
}

check_forms(){ #Vérifie si le formulaire est valide (2 option pour chaque select). $jl_ok avec les jours commandable
    i=1
    #on (ré)initialise les jour ok
    jl_ok=("")
    for fichier in tmp/* ; do #Pour chaque fichier dans tmp
        #On recupere le jour associé :
        jour_actuel=$(get_jour $fichier)

        #Renvoie le nombre de select avec au moin 2 options
        nb_form_ok=$(cat $fichier | grep -no '<select.*<option.*</option>.*<option.*</option>.*</select>'| sed 's/<\/select>/\~/g'|grep -o '~'|wc -w)
        
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
        var+=$i/
    done
    curl \
    -H "Title: "$1" Nouveau repas Disponibles" \
    -H "Tags: warning," \
    -d "$var" \
    ntfy.sh/repas_crous 1> /dev/null 2>/dev/null #envoie une requette de notification
}

wait_samedi(){ #Attend le prochain samedi a 00h01
    next_saturday=$(date -d 'next Saturday 12:01' +'%s')
    current_time=$(date +'%s')
    time_to_wait=$((next_saturday - current_time))
    curl -H "Title: Attente jusqu'au prochain Samedi" -d "temp: $time_to_wait" ntfy.sh/debug_repas_crous 1> /dev/null 2>/dev/null #envoie une notification de démarrage
    echo $(date '+%y-%m-%d %H:%M:%S')" WARNING  Attente jusqu'au prochain samedi a 00h01, temp: $time_to_wait"
    sleep $time_to_wait
    curl -H "Title: Redémarage Script" -d "En attente de repas" ntfy.sh/debug_repas_crous 1> /dev/null 2>/dev/null #envoie une notification de démarrage
}

while true ; do
    reset
    while true ; do #tant que nb_repas est strictement inférieur a 2
        download_index
        download_secondaires
        if [ "$nb_repas" -gt 0 ]; then
            break
        fi
        echo $(date '+%y-%m-%d %H:%M:%S')" NOTICE Aucun repas disponible prochaine tentative dans 60s"
        sleep 60
    done
    echo $(date '+%y-%m-%d %H:%M:%S')" WARNING $nb_repas repas disponibles"
    while [ "$nb_repas" -lt 10 ]; do #Tant que le nombre de repas est inférieur a 10
        download_index
        download_secondaires
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

        #Si le nb de repas >9 aou que le contenue de pause est 1 on arrette le 
        if [ "$nb_repas" -gt 9 ] || [ "$(cat pause)" -eq 1 ]; then
            break
        fi
        echo $(date '+%y-%m-%d %H:%M:%S')" NOTICE En attente de nouveau repas, prochaine tentative dans 60s"
        sleep 60
    done
    wait_samedi
done