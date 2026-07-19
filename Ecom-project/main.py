import os, pandas as pd
from sqlalchemy import create_engine, inspect, MetaData, text
from create_config_file import get_cfg

def get_engine():
    '''
    config = configparser.ConfigParser()
    config.read('config.ini')
    creds = config['mysql_db']
    '''
    creds = get_cfg('mysql_db')

    conn_str = f"mysql+pymysql://{creds['user']}:{creds['password']}@{creds['host']}:{creds['port']}/{creds['db']}"
    return(create_engine(conn_str))

#Get the table load order as per the PK-FK constraints defined in the MySQL Database
def get_load_order(data_dir, engine, inspector, table_list):
    
    metadata = MetaData()
    metadata.reflect(bind=engine, only=table_list)
    load_order = metadata.sorted_tables
    tablenames = [tbl.name for tbl in load_order]

    return (tablenames)

def load_data_to_db(data_dir):
    engine = get_engine()
    inspector = inspect(engine)
    
    file_tbl_map = {}
    for file in os.listdir(data_dir):
        tblname = file.split('.')[0]
        if file.endswith('.csv') and inspector.has_table(tblname):
            file_tbl_map[tblname] = file

    tbl_load_order = get_load_order(data_dir, engine=engine, inspector=inspector, table_list=file_tbl_map.keys())

    for table in tbl_load_order:
        tblname = table
        file = f'{tblname}.csv'
        print(f'Loading {file} into {tblname}...')
        df = pd.read_csv(os.path.join(data_dir,file))
        with engine.begin() as conn:
            conn.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
            conn.execute(text(f"TRUNCATE {tblname};"))
            df.to_sql(tblname, con=conn, if_exists='append', index=False)
            conn.execute(text("SET FOREIGN_KEY_CHECKS = 1"))
        print(pd.read_sql(f'select "{tblname}" as tblname, count(*) from {tblname};', con=engine))

if __name__ == '__main__':
    load_data_to_db('datafiles/')
    #get_load_order()