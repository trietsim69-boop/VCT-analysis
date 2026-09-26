from pathlib import Path


def newest_snapshot(pattern: str = "vct_*.duckdb") -> str:
    """The most recent dated file in data/raw/ (default: vct_YYYY-MM-DD.duckdb), so a new
    snapshot needs no code change."""
    snaps = sorted(Path("data/raw").glob(pattern))
    assert snaps, f"no data/raw/{pattern} — see data/raw/README.md"
    return str(snaps[-1])
