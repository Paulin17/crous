import requests,datetime,sys,os
from fonctions import *

LOG_FILE = f"LOG/{datetime.datetime.now().strftime('%Y-%m-%d_%Hh-%Mm-%Ss')}.log"
os.makedirs("LOG", exist_ok=True)


if __name__ == "__main__":
    log(LOG_FILE,"Démarrage du script")
    while True:
        break

