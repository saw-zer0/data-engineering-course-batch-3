import io
import logging
from pathlib import Path

import psycopg2
from psycopg2.extras import execute_values
import pandas as pd

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)

logger = logging.getLogger(__name__)


DB_CONFIG = dict(
    dbname="ride_share",
    user="admin",
    password="password123",
    host="localhost"
)

def health_check(conn):
    with conn.cursor() as cursor:
        cursor.execute("select 1")
        cursor.fetchone()
        logger.info("health check: works fine")

def truncate_rides(conn):
    with conn.cursor() as cursor:
        cursor.execute(f'TRUNCATE TABLE rides;')
    conn.commit()

def load_batch(conn, batch_data):
    print(batch_data[0])
    insert_query = """
    INSERT INTO rides (
    ride_id,
    driver_name,
    passenger_name,
    pickup_city,
    dropoff_city,
    fare_amount,
    ride_distance_km,
    ride_status,
    requested_at,
    completed_at,
    rating,
    payment_method
    ) VALUES %s
    ON CONFLICT (ride_id)
    DO NOTHING;
    """
    template = """
    ( %s, %s, %s, %s, %s, %s, %s, %s, %s, 
    NULLIF(%s,'')::TIMESTAMP, 
    NULLIF(%s,'')::NUMERIC, 
    NULLIF(%s,'')
    )
    """
    with conn.cursor() as cursor:
        execute_values(cursor, insert_query,batch_data, template)
        logger.info(f"total rows affected: {cursor.rowcount}")
    conn.commit()

def filter_file(conn, files):
    file_query = "SELECT filename FROM processed_files;"
    with conn.cursor() as cur:
        cur.execute(file_query)
        rows = {row[0] for row in cur.fetchall()}
        print(rows, files)
        return set(files - rows)

def insert_processed_file(conn, filename, rowcount):
    insert_query = """
    INSERT INTO processed_files(
    filename,
    row_count
    ) VALUES(%s,%s)
    """
    row_data = (filename, rowcount)
    with conn.cursor() as cur:
        cur.execute(insert_query, row_data)
        logger.info(f"Added file {filename}")
    conn.commit()
        
def main():
    chunk_size = 1000
    file_pattern = "rides_*.csv"
    csv_path = Path("data")
    files = {f.name for f in csv_path.glob(file_pattern)}
    print(files)
    col_dtype = {
        "completed_at":str,
        "rating": str,
        "payment_method": str
    }

    try:
        with psycopg2.connect(**DB_CONFIG) as conn:
            health_check(conn)
            filtered_files = filter_file(conn, files)
            print(filtered_files)
            for file in filtered_files:
                logger.info(f"Processing file: {file}")
                chunk_counter = 0
                total_rows = 0
                for df_chunk in pd.read_csv(csv_path/file, chunksize=chunk_size, keep_default_na=False, dtype=col_dtype):
                    chunk_counter +=1
                    total_rows+=len(df_chunk)
                    print(chunk_counter, total_rows)
                    batch_data = df_chunk.values.tolist()
                    print(batch_data[0])
                    load_batch(conn, batch_data)
                insert_processed_file(conn, file, total_rows)
            logger.info("Finished loading Script.")
    except psycopg2.OperationalError as e:
        logger.critical("Failed to connect db!!!")
        raise e
    except Exception as e:
        logger.error("An error occured")
        raise e
    finally:
        logger.info("Exiting...")

if __name__ == "__main__":
    main()