#!/usr/bin/env python3
"""
Mapper pour analyser l'activité des utilisateurs
Input: ratings.dat (UserID::MovieID::Rating::Timestamp)
Output: UserID Rating
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
            user_id = parts[0]
            rating = parts[2]
            print(f"{user_id}\t{rating}")
    except Exception as e:
        sys.stderr.write(f"Erreur parsing: {line}\n")
        continue
