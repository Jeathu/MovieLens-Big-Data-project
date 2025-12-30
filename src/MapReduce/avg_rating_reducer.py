#!/usr/bin/env python3
"""
Reducer pour calculer la moyenne des ratings par film
Input: MovieID Rating (sorted by MovieID)
Output: MovieID AvgRating NumRatings
"""
import sys




current_movie = None
rating_sum = 0
rating_count = 0



for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        movie_id, rating = line.split('\t')
        rating = float(rating)
        # Si on change de film, on émet le résultat du film précédent
        if current_movie and current_movie != movie_id:
            avg_rating = rating_sum / rating_count
            print(f"{current_movie}\t{avg_rating:.2f}\t{rating_count}")
            rating_sum = 0
            rating_count = 0
        current_movie = movie_id
        rating_sum += rating
        rating_count += 1
    except Exception as e:
        sys.stderr.write(f"Erreur reducer: {line}\n")
        continue


# Émettre le dernier film
if current_movie:
    avg_rating = rating_sum / rating_count
    print(f"{current_movie}\t{avg_rating:.2f}\t{rating_count}")
