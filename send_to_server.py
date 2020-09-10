import httplib, urllib
import sqlite3
import requests
import json

#TEMPERATURE_SERVER_URL = "crowdcare.vipserv.org"
TEMPERATURE_SERVER_URL = "localhost:3000"

def read_db_and_send():
  conn = sqlite3.connect('test.db')
  c = conn.cursor()

  r = []
  for row in c.execute('SELECT * FROM temperatures ORDER BY created_at'):
    r = [{
      "serial_number": row[1],
      "value": row[2],
      "created_at": row[3]
    }]

  print r
  send_data(r)

def send_data(rows):
  r = requests.post('http://' + TEMPERATURE_SERVER_URL + '/temperatures/', json={"temperatures": rows})
  #r = requests.post('http://' + TEMPERATURE_SERVER_URL + '/temperatures/', temperatures=rows)

  headers = {'Content-type': 'application/json'}
  print(r.status_code)
  params = urllib.urlencode({"temperatures": rows})
  #params = json.dumps({"temperatures": rows})
  #headers = {"Content-type": "content/json", "Accept": "text/plain"}
  #headers = {"Content-type": "application/x-www-form-urlencoded", "Accept": "text/plain"}
  #conn = httplib.HTTPConnection(TEMPERATURE_SERVER_URL)
  #conn.request("POST", "/temperatures/", params, headers)
  #response = conn.getresponse()
  #print response.status, response.reason

  # data = response.read()
  #conn.close()

read_db_and_send()
