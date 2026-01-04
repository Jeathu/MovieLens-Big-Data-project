#!/usr/bin/env python3
"""
Reducer pour compter les films par genre
Input: Genre 1 (sorted by Genre)
Output: Genre Count
"""
import sys



current_genre = None
count = 0


for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    try:
        genre, val = line.split('\t')
        val = int(val)
        if current_genre and current_genre != genre:
            print(f"{current_genre}\t{count}")
            count = 0

        current_genre = genre
        count += val
    except Exception as e:
        sys.stderr.write(f"Erreur reducer: {line}\n")
        continue


# emettre le dernier genre
if current_genre:
    print(f"{current_genre}\t{count}")
