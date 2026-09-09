CREATE TABLE processed_files(
    filename VARCHAR(200) PRIMARY KEY,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    row_count INTEGER
)