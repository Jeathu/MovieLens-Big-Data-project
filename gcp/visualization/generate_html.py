cat > ~/generate_html_report.py << 'EOF'
#!/usr/bin/env python3
import os, html
from datetime import datetime
from collections import Counter

MOVIES_PATH = os.path.expanduser("~/ml-1m/movies.dat")
RATINGS_PATH = os.path.expanduser("~/ml-1m/ratings.dat")
AVG_RATINGS_TSV = os.path.expanduser("~/results/avg_ratings.tsv")

def load_movies():
    movies = {}
    with open(MOVIES_PATH, "r", encoding="latin-1") as f:
        for line in f:
            p = line.strip().split("::")
            if len(p) >= 3:
                movies[int(p[0])] = (p[1], p[2])
    return movies

def load_rating_distribution():
    c = Counter()
    total = 0
    with open(RATINGS_PATH, "r", encoding="latin-1") as f:
        for line in f:
            p = line.strip().split("::")
            if len(p) >= 3:
                r = int(float(p[2]))
                c[r] += 1
                total += 1
    return c, total

def load_avg_ratings():
    data = []
    with open(AVG_RATINGS_TSV, "r", encoding="utf-8") as f:
        for line in f:
            p = line.strip().split("\t")
            if len(p) >= 3:
                try:
                    mid = int(p[0]); avg = float(p[1]); cnt = int(p[2])
                    data.append((mid, avg, cnt))
                except:
                    pass
    return data

def main():
    for path in [MOVIES_PATH, RATINGS_PATH, AVG_RATINGS_TSV]:
        if not os.path.exists(path):
            raise SystemExit(f"Fichier manquant: {path}")

    movies = load_movies()
    dist, total = load_rating_distribution()
    avg_data = load_avg_ratings()

    top_pop = sorted(avg_data, key=lambda x: x[2], reverse=True)[:15]
    top_rated = sorted([x for x in avg_data if x[2] >= 200], key=lambda x: x[1], reverse=True)[:15]

    def movie_title(mid):
        return movies.get(mid, (str(mid), ""))[0]

    def row_pop(x):
        mid, avg, cnt = x
        return f"<tr><td>{html.escape(movie_title(mid))}</td><td>{cnt}</td><td>{avg:.2f}</td></tr>"

    def row_rated(x):
        mid, avg, cnt = x
        return f"<tr><td>{html.escape(movie_title(mid))}</td><td>{avg:.2f}</td><td>{cnt}</td></tr>"

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Mini CSS propre
    css = """
    body{font-family:Arial, sans-serif; margin:20px; background:#0b0f19; color:#e6e6e6;}
    .card{background:#121a2a; border:1px solid #26324a; border-radius:12px; padding:16px; margin-bottom:16px;}
    h1{margin:0 0 6px 0;}
    .grid{display:grid; grid-template-columns:repeat(3,1fr); gap:12px;}
    .kpi{font-size:22px; font-weight:bold;}
    table{width:100%; border-collapse:collapse; margin-top:10px;}
    th,td{border-bottom:1px solid #26324a; padding:8px; text-align:left;}
    th{color:#b7c4ff;}
    .muted{color:#9aa6bd;}
    """

    kpi_movies = len(movies)
    kpi_ratings = total
    kpi_avg_votes = int(total / kpi_movies) if kpi_movies else 0

    bars = []
    vmax = max(dist.values()) if dist else 1
    for r in [1,2,3,4,5]:
        c = dist.get(r,0)
        pct = (c/total*100) if total else 0
        w = int((c/vmax)*300)
        bars.append(f"""
        <div style="margin:8px 0">
          <div class="muted">{r} étoiles — {c} ({pct:.2f}%)</div>
          <div style="background:#26324a; height:10px; border-radius:8px; overflow:hidden">
            <div style="width:{w}px; height:10px; background:#7aa2ff"></div>
          </div>
        </div>
        """)

    html_out = f"""
    <html>
    <head><meta charset="utf-8"><title>Rapport MovieLens</title><style>{css}</style></head>
    <body>
      <div class="card">
        <h1>Rapport MovieLens (Hadoop/Dataproc)</h1>
        <div class="muted">Généré le {now}</div>
      </div>

      <div class="grid">
        <div class="card"><div class="muted">Films</div><div class="kpi">{kpi_movies}</div></div>
        <div class="card"><div class="muted">Évaluations</div><div class="kpi">{kpi_ratings}</div></div>
        <div class="card"><div class="muted">Votes/film (moy.)</div><div class="kpi">{kpi_avg_votes}</div></div>
      </div>

      <div class="card">
        <h2>Distribution des notes</h2>
        {''.join(bars)}
      </div>

      <div class="card">
        <h2>Top 15 films les plus populaires</h2>
        <table><tr><th>Titre</th><th>Votes</th><th>Note moy.</th></tr>
        {''.join(row_pop(x) for x in top_pop)}
        </table>
      </div>

      <div class="card">
        <h2>Top 15 films les mieux notés (min 200 votes)</h2>
        <table><tr><th>Titre</th><th>Note moy.</th><th>Votes</th></tr>
        {''.join(row_rated(x) for x in top_rated)}
        </table>
      </div>
    </body>
    </html>
    """

    outpath = "/tmp/rapport_movielens.html"
    with open(outpath, "w", encoding="utf-8") as f:
        f.write(html_out)
    print(outpath)

if __name__ == "__main__":
    main()
EOF

chmod +x ~/generate_html_report.py
python3 ~/generate_html_report.py
