import requests,datetime,sys,os
from fonctions import *
import time
from bs4 import BeautifulSoup
url = "https://crousandgo.crous-poitiers.fr/larochelle/categorie-produit/sites-la-rochelle/"
code = html_pars(url)
jours = list(find(code))
for repas in jours:
    a = (str(repas).split('<h2 class="woocommerce-loop-product__title">')[1])
    b = a.split('</h2></a>')[0]
    print(b)



LOG_FILE = f"LOG/{datetime.datetime.now().strftime('%Y-%m-%d_%Hh-%Mm-%Ss')}.log"
os.makedirs("LOG", exist_ok=True)


if __name__ == "__main__":
    log(LOG_FILE,"Démarrage du script")
    while True:
        break

