#!/usr/bin/env python3
"""
Mapper pour calculer la moyenne des ratings par film
Input: ratings.dat (UserID::MovieID::Rating::Timestamp)
Output: MovieID \t Rating
"""
import sys

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    try:
        # Format: UserID::MovieID::Rating::Timestamp
        parts = line.split('::')
        if len(parts) >= 3:
            movie_id = parts[1]
            rating = parts[2]

            # Émettre: movie_id comme clé, rating comme valeur
            print(f"{movie_id}\t{rating}")
    except Exception as e:

        # Ignorer les lignes mal formatées
        sys.stderr.write(f"Erreur parsing: {line}\n")
        continue
