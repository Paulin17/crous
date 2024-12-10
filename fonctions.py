import datetime,requests
from bs4 import BeautifulSoup


def scrap(url):
    '''en entree un url pour faire une requete'''
    return requests.get(url)


def html_pars(url):
    '''fonction pour parser du code html via une requete (scrap())'''
    return BeautifulSoup(scrap(url).content, 'html.parser')

def find(html:str):
    '''fonction pour trouver tous les repas disponibles'''
    return html.find_all("a", {"class": "ast-loop-product__link"})

def log(file: str, message: str, level: str = "INFO") -> None:
    """
    Enregistre un message dans un fichier de log avec un niveau de gravité et un horodatage.

    :param file: Chemin du fichier de log où enregistrer les messages.
    :param message: Message à enregistrer.
    :param level: Niveau de gravité du message (par défaut "INFO").
    """
    log_message = f"{datetime.datetime.now().strftime('%y-%m-%d %H:%M:%S')} [{level}] {message}"
    print(log_message)
    with open(file, "a",encoding='UTF-8') as f:
        f.write(log_message + "\n")


def notif(title,data,url="https://ntfy.sh/repas_crous",tags="warning"):
    requests.post(url,
        data=data,
        headers={
            "Title": title,
            "Tags": tags
        })