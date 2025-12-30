#!/usr/bin/env python3
"""
Reducer pour analyser l'activité des utilisateurs
Input: UserID Rating (sorted by UserID)
Output: UserID  NumRatings AvgRating
"""
import sys




current_user = None
rating_sum = 0
rating_count = 0

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        user_id, rating = line.split('\t')
        rating = float(rating)

        if current_user and current_user != user_id:
            avg_rating = rating_sum / rating_count
            print(f"{current_user}\t{rating_count}\t{avg_rating:.2f}")
            rating_sum = 0
            rating_count = 0

        current_user = user_id
        rating_sum += rating
        rating_count += 1
    except Exception as e:
        sys.stderr.write(f"Erreur reducer: {line}\n")
        continue


# emettre le dernier utilisateur
if current_user:
    avg_rating = rating_sum / rating_count
    print(f"{current_user}\t{rating_count}\t{avg_rating:.2f}")
