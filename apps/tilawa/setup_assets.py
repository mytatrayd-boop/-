"""تجهيز الأصول مرة واحدة: نص المصحف (Tanzil عثماني، حفص) في SQLite + خط مجمع الملك فهد.

    python setup_assets.py

لا تُرفع الأصول إلى git (assets/ مستثنى): الخط ملك لمجمع الملك فهد، والنص يُنزَّل من مصدره.
"""
import io, json, sqlite3, tarfile, urllib.request, zipfile, xml.etree.ElementTree as ET
from pathlib import Path

ASSETS = Path(__file__).parent / "assets"
DB = ASSETS / "quran.db"
FONT = ASSETS / "hafs.otf"
TANZIL_IN_WHEEL = "quran_transcript/quran-script/quran-uthmani-without-pause-sajda-hizb-marks.xml"


def fetch(url):
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()


def get_font():
    meta = json.loads(fetch("https://registry.npmjs.org/kfgqpc-uthmanic-script-hafs-regular/latest"))
    with tarfile.open(fileobj=io.BytesIO(fetch(meta["dist"]["tarball"]))) as t:
        FONT.write_bytes(t.extractfile("package/arabic.otf").read())


def get_tanzil_xml():
    # نسخة Tanzil (Uthmani 1.1) مضمّنة كما هي داخل حزمة quran-transcript على PyPI
    meta = json.loads(fetch("https://pypi.org/pypi/quran-transcript/0.6.4/json"))
    wheel = next(u["url"] for u in meta["urls"] if u["filename"].endswith(".whl"))
    return zipfile.ZipFile(io.BytesIO(fetch(wheel))).read(TANZIL_IN_WHEEL)


def build_db(xml_bytes):
    root = ET.fromstring(xml_bytes)
    DB.unlink(missing_ok=True)
    con = sqlite3.connect(DB)
    con.executescript("""
        CREATE TABLE surah (id INTEGER PRIMARY KEY, name TEXT, ayat INTEGER);
        CREATE TABLE ayah (surah INTEGER, ayah INTEGER, text TEXT, PRIMARY KEY (surah, ayah));
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
    """)
    for s in root.findall("sura"):
        ayat = s.findall("aya")
        con.execute("INSERT INTO surah VALUES (?,?,?)", (int(s.get("index")), s.get("name"), len(ayat)))
        con.executemany("INSERT INTO ayah VALUES (?,?,?)",
                        [(int(s.get("index")), int(a.get("index")), a.get("text")) for a in ayat])
    con.execute("INSERT INTO meta VALUES ('source', 'Tanzil Quran Text (Uthmani, Version 1.1) — tanzil.net — CC BY 3.0, verbatim')")
    con.commit()
    total = con.execute("SELECT COUNT(*) FROM ayah").fetchone()[0]
    surahs = con.execute("SELECT COUNT(*) FROM surah").fetchone()[0]
    con.close()
    assert (total, surahs) == (6236, 114), f"نص ناقص: {total} آية، {surahs} سورة"
    return total


if __name__ == "__main__":
    ASSETS.mkdir(exist_ok=True)
    if not FONT.exists():
        get_font()
    print("الخط:", FONT)
    print("الآيات:", build_db(get_tanzil_xml()), "→", DB)
