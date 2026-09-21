from pathlib import Path


def newest_snapshot() -> str:
    """The most recent data/raw/vct_YYYY-MM-DD.duckdb, so a new snapshot needs no code change."""
    snaps = sorted(Path("data/raw").glob("vct_*.duckdb"))
    assert snaps, "no data/raw/vct_*.duckdb — see data/raw/README.md"
    return str(snaps[-1])
