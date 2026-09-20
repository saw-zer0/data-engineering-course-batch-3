import logging
import json
import os
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv
from psycopg2 import connect
from psycopg2.extras import execute_batch


logging.basicConfig(
        level=logging.INFO,
    format="%(asctime)s  %(levelname)s Line %(lineno)d %(message)s",

    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.FileHandler("load.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)
load_dotenv()

DB_CONFIG = {
    "host": os.getenv("MOVIE_DB_HOST"),
    "port": os.getenv("MOVIE_DB_PORT"),
    "user": os.getenv("MOVIE_DB_USER"),
    "password": os.getenv("MOVIE_DB_PASSWORD"),
    "dbname": os.getenv("MOVIE_DB_NAME")
}

def load_dim_movie(conn, data):
    insert_query = """
        INSERT INTO dim_movie (imdb_id, title, plot, poster_url)
        VALUES(%(imdb_id)s, %(title)s, %(plot)s, %(poster_url)s)
        ON CONFLICT(imdb_id) DO NOTHING;
    """
    with conn.cursor() as cur:
        execute_batch(cur, insert_query, data)
    conn.commit()
    logger.info(f"Loaded {len(data)} records into dim_movie table.")

def load_dim_director(conn, directors):
    insert_query = """
        INSERT INTO dim_director (director_name)
        VALUES (%s)
        ON CONFLICT DO NOTHING;
    """
    director_list = [(item, ) for item in directors]
    with conn.cursor() as cur:
        execute_batch(cur, insert_query, director_list)
    conn.commit()
    logger.info(f"Loaded {len(directors)} records into dim_director table.")

def load_dim_country(conn, countries):
    insert_query = """
        INSERT INTO dim_country (country_name)
        VALUES (%s)
        ON CONFLICT DO NOTHING;
    """
    country_list = [(item, ) for item in countries]
    with conn.cursor() as cur:
        execute_batch(cur, insert_query, country_list)
    conn.commit()
    logger.info(f"Loaded {len(countries)} records into dim_country table.")

def load_dim_language(conn, languages):
    insert_query = """
        INSERT INTO dim_language (language_name)
        VALUES (%s)
        ON CONFLICT DO NOTHING;
    """
    language_list = [(item, ) for item in languages]
    with conn.cursor() as cur:
        execute_batch(cur, insert_query, language_list)
    conn.commit()
    logger.info(f"Loaded {len(languages)} records into dim_language table.")

def load_dim_genre(conn, genres):
    insert_query = """
        INSERT INTO dim_genre (genre_name)
        VALUES (%s)
        ON CONFLICT DO NOTHING;
    """
    genre_list = [(item, ) for item in genres]
    with conn.cursor() as cur:
        execute_batch(cur, insert_query, genre_list)
    conn.commit()
    logger.info(f"Loaded {len(genres)} records into dim_genre table.")

def load_bridge_movie_genre(conn, movies, lookup):
    rows = []
    for movie in movies:
        imdb_id = movie["imdb_id"]
        for genre in movie["genre"]:
            row = {
                "movie_key": lookup["movie"][imdb_id],
                "genre_key": lookup["genre"][genre]
            }
            rows.append(row)
    # insert into bridge table
    insert_query = """
            INSERT INTO bridge_movie_genre(movie_key, genre_key)
            VALUES(%(movie_key)s, %(genre_key)s)
            ON CONFLICT DO NOTHING;
        """
    with conn.cursor() as cur:
        execute_batch(cur,insert_query, rows)
    conn.commit()
    logger.info(f"Loaded {len(rows)} records into bridge_movie_genre table.")

def load_dim_certificate(conn, certificates):
    insert_query = """
        INSERT INTO dim_certificate (rated_code)
        VALUES (%s)
        ON CONFLICT DO NOTHING;
    """
    certificates_list = [(item, ) for item in certificates]
    with conn.cursor() as cur:
        execute_batch(cur, insert_query, certificates_list)
    conn.commit()
    logger.info(f"Loaded {len(certificates)} records into dim_certificate table.")

def load_lookup_dim(conn):
    movie_query = "SELECT movie_key,imdb_id from dim_movie;"
    director_query = "SELECT * FROM dim_director;"
    country_query = "SELECT * FROM dim_country;"
    language_query = "SELECT * FROM dim_language;"
    certificate_query = "SELECT * FROM dim_certificate;"
    genre_query = "SELECT * FROM dim_genre;"
    release_date_query = "SELECT date_key FROM dim_release_date;"

    lookup = {}
    with conn.cursor() as cur:
        cur.execute(movie_query)
        lookup["movie"] = {i[1]:i[0] for i in cur.fetchall()}
        cur.execute(director_query)
        lookup["director"] = {i[1]:i[0] for i in cur.fetchall()}
        cur.execute(country_query)
        lookup["country"] = {i[1]:i[0] for i in cur.fetchall()}
        cur.execute(language_query)
        lookup["language"] = {i[1]:i[0] for i in cur.fetchall()}
        cur.execute(certificate_query)
        lookup["certificate"] = {i[1]:i[0] for i in cur.fetchall()}
        cur.execute(genre_query)
        lookup["genre"] = {i[1]:i[0] for i in cur.fetchall()}
        cur.execute(release_date_query)
        lookup["release_date"] = {i[0]:True for i in cur.fetchall()}
    return lookup

def build_fact_rows(conn, data_list, lookup):
    rows = []
    for data in data_list:
        movie_key = lookup["movie"].get(data["imdb_id"])
        if movie_key is None:
            logger.warning(f"Movie key not found for {data['imdb_id']}")
            continue
        director_key = lookup["director"].get(data["director_name"])
        if director_key is None:
            logger.warning(f"Director key not found for {data['director_name']}")
            continue
        country_key = lookup["country"].get(data["country_name"])
        if country_key is None:
            logger.warning(f"Country key not found for {data['country_name']}")
            continue
        language_key = lookup["language"].get(data["language_name"])
        if language_key is None:
            logger.warning(f"Language key not found for {data['language_name']}")
            continue
        certificate_key = lookup["certificate"].get(data["rated"])
        if certificate_key is None:
            logger.warning(f"Certificate key not found for {data['rated']}")
            continue
        release_date = datetime.strptime(data["release_date"], "%d %b %Y").date()
        release_date_int = int(release_date.strftime("%Y%m%d"))
        release_date_key = release_date_int if lookup["release_date"].get(release_date_int) else None
        if release_date_key is None:
            logger.warning(f"Release date key not found for {release_date.strftime('%Y%m%d')}")
            continue

        runtime_minutes = int(data["runtime_minutes"].split(" ")[0]) if data["runtime_minutes"] != "N/A" else None
        imdb_rating = float(data["imdb_rating"]) if data["imdb_rating"] != "N/A" else None
        imdb_votes = int(data["imdb_votes"].replace(",", "")) if data["imdb_votes"] != "N/A" else None
        metascore = int(data["metascore"]) if data["metascore"] != "N/A" else None
        ratings = data["ratings"]
        rotten_tomatoes_value =[rating["Value"] for rating in ratings if rating["Source"] == "Rotten Tomatoes" ]
        rotten_tomatoes_pct = int(rotten_tomatoes_value[0].replace("%", "")) if rotten_tomatoes_value else None
        box_office_usd = int(data["box_office_usd"].replace("$", "").replace(",", "")) if data["box_office_usd"] != "N/A" else None
        row = {
            "movie_key": movie_key,
            "director_key": director_key,
            "country_key": country_key,
            "language_key": language_key,
            "certificate_key": certificate_key,
            "release_date_key": release_date_int,
            "runtime_minutes": runtime_minutes,
            "imdb_rating": imdb_rating,
            "imdb_votes": imdb_votes,
            "metascore": metascore,
            "rotten_tomatoes_pct": rotten_tomatoes_pct,
            "box_office_usd": box_office_usd
        }
        rows.append(row)
    return rows

def load_fact_movie(conn, rows):
    insert_query = """
        INSERT INTO fact_movie(
            movie_key, director_key, country_key, language_key,
            certificate_key, release_date_key, runtime_minutes,
            imdb_rating, imdb_votes, metascore, rotten_tomatoes_pct,
            box_office_usd)
        VALUES (%(movie_key)s, %(director_key)s, %(country_key)s, %(language_key)s,
                %(certificate_key)s, %(release_date_key)s, %(runtime_minutes)s,
                %(imdb_rating)s, %(imdb_votes)s, %(metascore)s,
                %(rotten_tomatoes_pct)s, %(box_office_usd)s)
        ON CONFLICT (movie_key ) DO NOTHING;
    """
    with conn.cursor() as cur:
        execute_batch(cur, insert_query, rows)
    conn.commit()
    logger.info(f"Loaded {len(rows)} records into fact_movie table.")

def get_db_conn(config):
    try:
        conn = connect(**config)
        logger.info("Connected to database.")
        return conn
    except Exception as e:
        logger.error("Unable to connect with database!!!")
        raise e

def load():
    # list all files in data/raw
    BASE_PATH = Path("data/raw")
    conn = get_db_conn(DB_CONFIG)
    files = BASE_PATH.glob("tt*.json")
    data_list = []
    directors, countries, languages, genres, certificates = set(), set(), set(), set(), set()

    # loop through files one by one
    for file in files:
        # parse json
        with open(file, "r") as f:
            data=json.load(f)
            mapped_data = {
                "imdb_id": data["imdbID"],
                "title": data["Title"],
                "plot": None if data["Plot"] == "N/A" else data["Plot"] ,
                "poster_url": None if data["Poster"]== "N/A" else data["Poster"],
                "director_name": str(data["Director"]).split(",")[0].strip(),
                "country_name": str(data["Country"]).split(",")[0].strip(),
                "language_name": str(data["Language"]).split(",")[0].strip(),
                "genre": [genre.strip() for genre in str(data["Genre"]).split(",")],
                "rated": data["Rated"],
                "release_date": data["Released"],
                "runtime_minutes": data["Runtime"],
                "imdb_rating": data["imdbRating"],
                "imdb_votes": data["imdbVotes"],
                "metascore": data["Metascore"],
                "ratings": data["Ratings"],
                "box_office_usd": data["BoxOffice"]
            }
            data_list.append(mapped_data)
            directors.add(mapped_data["director_name"])
            countries.add(mapped_data["country_name"])
            languages.add(mapped_data["language_name"])
            genres.update(mapped_data["genre"])
            certificates.add(mapped_data["rated"])

    # load dim tables
        # movie, director, country, language
        # genre, bridge_movie_genre
        # certificate, release_date
    load_dim_movie(conn, data_list)
    load_dim_director(conn, directors)
    load_dim_country(conn, countries)
    load_dim_language(conn, languages)
    load_dim_genre(conn, genres)
    load_dim_certificate(conn, certificates)
    lookup = load_lookup_dim(conn)
    load_bridge_movie_genre(conn, data_list, lookup)
    # transform data for fact table
    # load fact table
    fact_rows = build_fact_rows(conn, data_list, lookup)
    load_fact_movie(conn, fact_rows)




load()
