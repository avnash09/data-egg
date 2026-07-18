import configparser, os

config = configparser.ConfigParser()
config['mysql_db'] = {
    'user': 'root',
    'password': os.environ['mysqldb_pwd'],
    'host': 'localhost',
    'port': 3306,
    'db': 'hr_db'
}

with open('config.ini', mode='w') as f:
    config.write(f)

with open('config.ini', mode='r') as f:
    print(f.read())
