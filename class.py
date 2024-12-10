class Repas:

    def __init__(self, carac):
        self.caracteristiques = carac
        self.jour = self.caracteristiques[3]
        self.nb_jour = None
        self.mois = None
        self.nb_mois = None
        self.annee = None
        self.vegetarien = "végétarien" in self.caracteristiques
        self.attributs()

    def attributs(self):
        t = 0
        if len(self.caracteristiques) > 8:
            t = 1
        self.nb_jour = self.caracteristiques[4+t] if self.caracteristiques[4+t].isdigit() else None
        self.nb_mois = self.str_to_dec(self.caracteristiques[5+t])
        self.mois = self.caracteristiques[5+t]
        self.annee = self.caracteristiques[7+t] if self.caracteristiques[7+t].isdigit() else None

    def str_to_dec(self, mois:str):
        mois_s = {"Janvier": "01", "Février": "02", "Mars": "03", "Avril": "04", "Mai": "05", "Juin": "06", "Juillet": "07", "Août": "08", "Septembre": "09", "Octobre": "10", "Novembre": "11", "Décembre": "12"}
        return mois_s[mois]

    def vege(self):
        if self.vegetarien:
            return "Végétarien"
        return "Normal"

    def __str__(self):
        return f"{self.jour.capitalize()} {self.nb_jour} {self.mois} {self.annee} {self.vege()}"

de = ['05_Repas', 'La', 'Rochelle', 'mercredi', '', '11', 'Décembre', '', '2024', '', 'végétarien']
repas = Repas(de)

print(repas.__str__())
