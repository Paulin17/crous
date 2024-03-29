curl \
        -H "Title: Demarrage script" \
        -H "Tags: heavy_check_mark," \
        -d "   En attente de repas" \
        ntfy.sh/repas_crous; 2>/dev/null #envoie une notification de démarrage

url=https://crousandgo.crous-poitiers.fr/larochelle/categorie-produit/sites-la-rochelle/ #URL Crous

#Suppression du répertoire
rm -R tmp/ 2>/dev/null

download_index(){ #Met dans $code_html le code de la page principale 
    code_html=$(curl -s "$url")
}

detection_repas(){ #Détecte si des repas sont en ligne, renvoie $nb_repas+1 repas disponible

    #Extraction des url des repas.
    #              affiche le code   Récupere les href        cherche la chaine         cut le href    enleve les doublons
    repas_links=$(echo $code_html | grep -oE 'href="([^"#]+)"'|grep 'repas-la-rochelle'| cut -d'"' -f2|uniq)
  
    #Compte les espaces
    nb_repas=$(echo $repas_links|grep -o ' ' | wc -l)+1

    # Vérifiez si le nombre d'espaces est supérieur à 0( ca veut dire que y a des repas.)
    if [ "$nb_repas" -gt 1 ];
    then
        echo "Il y a des repas" #Affiche dans la console
        curl \
            -H "Title: $(($nb_repas+1)) Repas Disponibles" \
            -H "Tags: warning," \
            -d "Debut du traitement des repas" \
            ntfy.sh/repas_crous #envoie une requette de notification
        get_jour
        verification_formulaire
    else
            echo "Pas de repas"
    fi
}
get_jour(){ #Nécessite la liste des repas, renvoie la liste des jour qui sont dispo ($jl) et stoke les page dans tpm/
    jl=''
    rm -R tmp/
    mkdir tmp/
    for link in $repas_links; do
        code_temp=$(curl -sL "$link") #Telecharge la page
        traitement_temp=$(echo $code_temp |grep -oP '<h1.*?>(.*?)<\/h1>' | sed -e 's/<[^>]*>//g'|tr ' ' '_') #Récupere uniquement le contenue de H1 en remplacant par des tiret du bas les espaces
        jour=$(echo $traitement_temp |cut -d '_' -f 5) #Récupere le jour de la semaine
        
        #Si le prétraitement contient 'végétarien', on le specifie sinon c'st un repas normal.
        if grep "végétarien"<<< $traitement_temp;then
            type='Végétarien'
        else
            type='Normal'
        
        fi
        jl_type+=$jour-$type/ #Complemente la variable Jl(jours liste) avec les info du repas qui vient d'être traité
        echo $code_temp > "tmp/$traitement_temp.html"
    done

}

verification_formulaire(){ #Vérifie si le formulaire est valide (2 option pour chaque select)
    #"Renvoie" une liste (jl_ok) avec les jours commandable
    i=1
    jl_ok=''
    for fichier in tmp/*; do
        #on initialise les jour ok
        jour_actuel=$(echo "$jl_type"|cut -d '\' -f "$i")
        nb_form_ok=$(cat $fichier | grep -no '<select.*<option.*</option>.*<option.*</option>.*</select>'| sed 's/<\/select>/\~/g'|grep -o '~'|wc -w)
        if  [ "$nb_form_ok" -eq "6" ]; then
             echo "$jour_actuel - Formulaire OK : $nb_form_ok"
             jl_ok+=$jour_actuel/
        else
            echo "$jour_actuel - Formulaire incorect : $nb_form_ok"
        fi
        i=$(($i+1))
    done
    echo "liste des jour:$jl_ok"
    curl \
        -H "Title: Les formulaire complet :" \
        -d " $jl_ok" \
        ntfy.sh/repas_crous; #envoie une requette de notification
}


##Programe principales
while true ; do
    date '+%Y-%m-%d %H:%M:%S'
    download_index
    detection_repas
    get_jour
    echo 'Aucun repas, prochaine tentative dans 60s'
    sleep 55
done