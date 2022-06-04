import pandas as pd
import json
import urllib
import requests as rq

def get_oauth_token():
    url = "https://api.idealista.com/oauth/token"        
    authString = 'generate_your_string'    
    headers = {'Content-Type':'application/x-www-form-urlencoded;charset=UTF-8', 'Authorization':'Basic ' + authString}
    params = urllib.parse.urlencode({'grant_type':'client_credentials'})
    content = rq.post(url,headers = headers, params=params)
    bearer_token = json.loads(content.text)['access_token']
    return bearer_token

def search_api(token, url):  
    headers = {'Content-Type':'Content-Type: multipart/form-data;', 'Authorization':'Bearer ' + token}
    content = rq.post(url, headers = headers)    
    result = json.loads(content.text)

    #send the json data to text file 
    with open('C:/Users/leone/OneDrive/Documents/Playground/Datasets/data.json', 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii = False, indent = 4)
    
    return result

country = 'es' #values: es, it, pt
language = 'es' 
max_items = '100'
operation = 'rent' 
property_type = 'homes'
order = 'priceDown' 
#center = '41.3870154,2.1678584' #Plaça Catalunya 
center = '40.4169019,-3.7056721' #Puerta del Sol
distance = '60000'
sort = 'desc'
bankOffer = 'false'
fileName = "C:/Users/leone/OneDrive/Documents/Playground/Datasets/idealista-" + property_type + "-" + operation

df_tot = pd.DataFrame()

url = ('https://api.idealista.com/3.5/' + country + '/search?operation=' + operation + 
        '&maxItems=' + max_items +
        '&order=' + order +
        '&center=' + center +
        '&distance=' + distance +
        '&propertyType=' + property_type +
        '&sort=' + sort +
        '&numPage=%s' +
        '&language=' + language)  

a = search_api(get_oauth_token(), url)
df = pd.DataFrame.from_dict(a['elementList'])

df_tot = pd.concat([df_tot, df])
df_tot.to_csv(fileName + ".csv")
df_tot.to_json(fileName + ".json")
df_tot = df_tot.reset_index()