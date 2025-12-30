#!/usr/bin/env python3
"""
Mapper pour compter les films par genre
Input: movies.dat (MovieID::Title::Genres)
Output: Genre 1
"""
import sys



for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    try:
        # Format: MovieID::Title::Genres
        parts = line.split('::')
        if len(parts) >= 3:
            genres = parts[2]
            # Séparer les genres multiples
            for genre in genres.split('|'):
                genre = genre.strip()
                if genre:
                    print(f"{genre}\t1")
    except Exception as e:
        sys.stderr.write(f"Erreur parsing: {line}\n")
        continue
