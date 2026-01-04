cat > ~/generate_visualizations.py << 'EOF'
#!/usr/bin/env python3
import os, sys
from collections import Counter, defaultdict

MOVIES_PATH = os.path.expanduser("~/ml-1m/movies.dat")
RATINGS_PATH = os.path.expanduser("~/ml-1m/ratings.dat")
USERS_PATH = os.path.expanduser("~/ml-1m/users.dat")

AVG_RATINGS_TSV = os.path.expanduser("~/results/avg_ratings.tsv")   # movieId \t avg \t count
TOP_MOVIES_TSV  = os.path.expanduser("~/results/top_movies.tsv")   # rank \t movieId \t avg \t count (par ton reducer)
BAR_MAX = 24

def bar(value, vmax, width=BAR_MAX):
    if vmax <= 0: 
        return ""
    n = int(round((value / vmax) * width))
    return "█" * max(0, n)

def load_movies():
    movies = {}
    with open(MOVIES_PATH, "r", encoding="latin-1") as f:
        for line in f:
            parts = line.strip().split("::")
            if len(parts) >= 3:
                mid = int(parts[0])
                title = parts[1]
                genres = parts[2].split("|") if parts[2] else []
                movies[mid] = (title, genres)
    return movies

def load_ratings_basic():
    rating_counts = Counter()
    total = 0
    with open(RATINGS_PATH, "r", encoding="latin-1") as f:
        for line in f:
            parts = line.strip().split("::")
            if len(parts) >= 3:
                r = int(float(parts[2]))
                rating_counts[r] += 1
                total += 1
    return rating_counts, total

def load_users():
    # user_id::gender::age::occupation::zipcode
    gender_counts = Counter()
    age_counts = Counter()
    with open(USERS_PATH, "r", encoding="latin-1") as f:
        for line in f:
            parts = line.strip().split("::")
            if len(parts) >= 5:
                gender_counts[parts[1]] += 1
                age_counts[int(parts[2])] += 1
    return gender_counts, age_counts

def compute_activity_by_age():
    # activité = nb de notes par tranche d'âge (en utilisant users.dat + ratings.dat)
    user_age = {}
    with open(USERS_PATH, "r", encoding="latin-1") as f:
        for line in f:
            p = line.strip().split("::")
            if len(p) >= 3:
                user_age[int(p[0])] = int(p[2])

    age_votes = Counter()
    with open(RATINGS_PATH, "r", encoding="latin-1") as f:
        for line in f:
            p = line.strip().split("::")
            if len(p) >= 1:
                uid = int(p[0])
                age = user_age.get(uid)
                if age is not None:
                    age_votes[age] += 1
    return age_votes

def compute_gender_stats():
    # stats (utilisateurs, votes, note moyenne) par genre (H/F)
    user_gender = {}
    with open(USERS_PATH, "r", encoding="latin-1") as f:
        for line in f:
            p = line.strip().split("::")
            if len(p) >= 2:
                user_gender[int(p[0])] = p[1]

    votes = Counter()
    total_rating = defaultdict(float)
    count_rating = Counter()

    with open(RATINGS_PATH, "r", encoding="latin-1") as f:
        for line in f:
            p = line.strip().split("::")
            if len(p) >= 3:
                uid = int(p[0])
                r = float(p[2])
                g = user_gender.get(uid)
                if g:
                    votes[g] += 1
                    total_rating[g] += r
                    count_rating[g] += 1

    users_by_gender = Counter(user_gender.values())
    stats = {}
    for g in ["M", "F"]:
        u = users_by_gender.get(g, 0)
        v = votes.get(g, 0)
        avg = (total_rating[g] / count_rating[g]) if count_rating[g] else 0.0
        stats[g] = (u, v, avg)
    return stats

def load_avg_ratings():
    # movieId \t avg \t count
    data = []
    with open(AVG_RATINGS_TSV, "r", encoding="utf-8") as f:
        for line in f:
            p = line.strip().split("\t")
            if len(p) >= 3:
                try:
                    mid = int(p[0])
                    avg = float(p[1])
                    cnt = int(p[2])
                    data.append((mid, avg, cnt))
                except:
                    pass
    return data

def top_popular(movies, avg_data, k=15):
    # plus populaires = plus de votes (cnt)
    avg_data_sorted = sorted(avg_data, key=lambda x: x[2], reverse=True)[:k]
    return [(movies.get(mid, (str(mid), []))[0], cnt) for mid, avg, cnt in avg_data_sorted]

def top_rated(movies, avg_data, k=15, min_votes=200):
    # mieux notés = avg desc, avec filtre min_votes
    filtered = [x for x in avg_data if x[2] >= min_votes]
    filtered.sort(key=lambda x: x[1], reverse=True)
    top = filtered[:k]
    return [(movies.get(mid, (str(mid), []))[0], avg, cnt) for mid, avg, cnt in top]

def top_genres_by_votes(movies):
    # compter nb de votes par genre (movies + ratings)
    movie_genres = {}
    for mid, (title, genres) in movies.items():
        movie_genres[mid] = genres

    genre_votes = Counter()
    with open(RATINGS_PATH, "r", encoding="latin-1") as f:
        for line in f:
            p = line.strip().split("::")
            if len(p) >= 2:
                mid = int(p[1])
                for g in movie_genres.get(mid, []):
                    genre_votes[g] += 1

    return genre_votes.most_common(10)

def print_header(title):
    print("=" * 70)
    print(title.center(70))
    print("=" * 70)
    print()

def main():
    # checks
    for path in [MOVIES_PATH, RATINGS_PATH, USERS_PATH, AVG_RATINGS_TSV]:
        if not os.path.exists(path):
            print(f"[ERREUR] Fichier manquant: {path}")
            print("=> Vérifie que ~/ml-1m/*.dat existent et que ~/results/avg_ratings.tsv existe.")
            sys.exit(1)

    movies = load_movies()
    rating_counts, rating_total = load_ratings_basic()
    gender_counts, _ = load_users()

    avg_data = load_avg_ratings()

    # 1) Top 15 populaires
    print_header("TOP 15 FILMS LES PLUS POPULAIRES")
    pop = top_popular(movies, avg_data, k=15)
    vmax = max([c for _, c in pop]) if pop else 1
    for title, cnt in pop:
        print(f"{title[:28]:28}  {bar(cnt, vmax):24} {cnt:,}".replace(",", " "))

    print("\n")

    # 2) Top 15 mieux notés
    print_header("TOP 15 FILMS LES MIEUX NOTÉS (min 200 votes)")
    rated = top_rated(movies, avg_data, k=15, min_votes=200)
    vmax = max([a for _, a, _ in rated]) if rated else 5
    for title, avg, cnt in rated:
        print(f"{title[:28]:28}  {bar(avg, vmax):24} {avg:.2f}  ({cnt})")

    print("\n")

    # 3) Distribution des notes
    print_header("DISTRIBUTION DES NOTES")
    vmax = max(rating_counts.values()) if rating_counts else 1
    for r in [1,2,3,4,5]:
        c = rating_counts.get(r, 0)
        pct = (c / rating_total * 100) if rating_total else 0
        label = f"{r} étoiles"
        print(f"{label:12}  {bar(c, vmax):24} {c:,} ({pct:.2f}%)".replace(",", " "))

    print("\n")

    # 4) Top 10 genres
    print_header("TOP 10 GENRES PAR NOMBRE DE VOTES")
    topg = top_genres_by_votes(movies)
    vmax = max([c for _, c in topg]) if topg else 1
    for g, c in topg:
        print(f"{g[:28]:28}  {bar(c, vmax):24} {c:,}".replace(",", " "))

    print("\n")

    # 5) Activité par tranche d’âge
    print_header("ACTIVITÉ PAR TRANCHE D'ÂGE (nb de votes)")
    age_votes = compute_activity_by_age()
    top_age = sorted(age_votes.items(), key=lambda x: x[1], reverse=True)[:10]
    vmax = max([c for _, c in top_age]) if top_age else 1
    for age, c in top_age:
        print(f"{str(age)+' ans':12}  {bar(c, vmax):24} {c:,}".replace(",", " "))

    print("\n")

    # 6) Stats H/F
    print_header("STATISTIQUES PAR GENRE (HOMME/FEMME)")
    stats = compute_gender_stats()
    m_u, m_v, m_avg = stats["M"]
    f_u, f_v, f_avg = stats["F"]
    print(f"Hommes  (M) : {m_u:,} utilisateurs | {m_v:,} votes | Note moy: {m_avg:.2f}".replace(",", " "))
    print(f"Femmes  (F) : {f_u:,} utilisateurs | {f_v:,} votes | Note moy: {f_avg:.2f}".replace(",", " "))

    print("\n")

    # 7) Résumé
    print_header("RÉSUMÉ DES ANALYSES")
    total_movies = len(movies)
    total_ratings = rating_total
    total_users = gender_counts["M"] + gender_counts["F"]
    avg_votes_per_movie = int(total_ratings / total_movies) if total_movies else 0
    avg_votes_per_user  = int(total_ratings / total_users) if total_users else 0

    print(f"Total de films analysés     : {total_movies:10}")
    print(f"Total d'évaluations         : {total_ratings:10,}".replace(",", " "))
    print(f"Total d'utilisateurs        : {total_users:10}")
    print(f"Moyenne votes/film          : {avg_votes_per_movie:10}")
    print(f"Moyenne votes/utilisateur   : {avg_votes_per_user:10}")

if __name__ == '__main__':
    main()
EOF

chmod +x ~/generate_visualizations.py
