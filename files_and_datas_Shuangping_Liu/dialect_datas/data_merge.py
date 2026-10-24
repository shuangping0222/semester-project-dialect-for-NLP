from pathlib import Path
import pandas as pd

DATA_DIR = Path("~/Desktop/files/datas").expanduser()
OUT_WIDE = Path(r"all_vari_matrix.csv")

files = list(DATA_DIR.glob("*.csv"))
print("Found CSV files:", [f.name for f in files])

COL_ID = "NUM"
COL_CONCEPT = "WORD"
COL_STDIPA = "IPA_processed"

#find the data file
def site_from_filename(fp: Path) -> str:
    return fp.stem

rows = []
files = sorted(
    fp for fp in DATA_DIR.glob("*.csv")
    if fp.name != "sites.csv"
)

if not files:
    raise FileNotFoundError(f"No CSV files found in {DATA_DIR}")

for fp in files:
    site = site_from_filename(fp)
    df = pd.read_csv(fp)

    missing = [c for c in [COL_ID, COL_CONCEPT, COL_STDIPA] if c not in df.columns]
    if missing:
        raise ValueError(f"{fp.name} missing columns: {missing}. Columns are: {list(df.columns)}")

    tmp = df[[COL_ID, COL_CONCEPT, COL_STDIPA]].copy()
    tmp["site"] = site

    tmp[COL_STDIPA] = tmp[COL_STDIPA].astype(str).str.strip()
    tmp = tmp[(tmp[COL_STDIPA].notna()) & (tmp[COL_STDIPA] != "") & (tmp[COL_STDIPA].str.lower() != "nan")]

    rows.append(tmp)

long_all = pd.concat(rows, ignore_index=True)

def merge_variants(series):
    uniq = pd.unique(series.dropna())
    uniq = [str(x).strip() for x in uniq if str(x).strip() and str(x).strip().lower() != "nan"]
    return "/".join(uniq)

agg = (long_all
       .groupby(["site", COL_ID], as_index=False)
       .agg({
           COL_STDIPA: merge_variants,
           COL_CONCEPT: "first"
       }))

# pivot：site × num
wide = agg.pivot(index="site", columns=COL_ID, values=COL_STDIPA)


try:
    wide = wide.reindex(sorted(wide.columns, key=lambda x: int(x)), axis=1)
except Exception:
    pass

wide.to_csv(OUT_WIDE, encoding="utf-8-sig")
print("Saved:", OUT_WIDE)
print("Matrix shape (sites × concepts):", wide.shape)