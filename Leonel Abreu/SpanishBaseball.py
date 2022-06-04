import ssl
import urllib.request

ssl._create_default_https_context = ssl._create_unverified_context

with urllib.request.urlopen('https://www.rfebs.es/estadisticas/2021/liga/beisbol/05.htm#GAME.PLY') as response:
   html = response.read()

text_file = open("Partido1.html", "w")

file_content = str(html).replace("\\n", "")

n = text_file.write(file_content)
text_file.close()