tt=("test" "truc complet" "test2")

fn() {
    echo "Premier:$1"
    # Affiche tous les éléments sauf le premier
    var=""
    for i in "${@:2}"; do
        var+=$i/
    done
    echo $var
}

fn "${tt[@]}"

# Affiche un message de succès
echo "Script corrigé avec succès !"