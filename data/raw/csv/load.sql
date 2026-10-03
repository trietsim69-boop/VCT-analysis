COPY kill_matrix FROM 'data/raw/csv/kill_matrix.csv' (FORMAT 'csv', HEADER 1, delimiter ',', quote '"');
COPY maps FROM 'data/raw/csv/maps.csv' (FORMAT 'csv', HEADER 1, delimiter ',', quote '"');
COPY matches FROM 'data/raw/csv/matches.csv' (FORMAT 'csv', HEADER 1, delimiter ',', quote '"');
COPY notables FROM 'data/raw/csv/notables.csv' (FORMAT 'csv', HEADER 1, delimiter ',', quote '"');
COPY players FROM 'data/raw/csv/players.csv' (FORMAT 'csv', HEADER 1, delimiter ',', quote '"');
COPY player_map FROM 'data/raw/csv/player_map.csv' (FORMAT 'csv', HEADER 1, delimiter ',', quote '"');
COPY rounds FROM 'data/raw/csv/rounds.csv' (FORMAT 'csv', HEADER 1, delimiter ',', quote '"');
COPY teams FROM 'data/raw/csv/teams.csv' (FORMAT 'csv', HEADER 1, delimiter ',', quote '"');
