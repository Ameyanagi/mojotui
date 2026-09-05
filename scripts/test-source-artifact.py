"""Exercise the shared handoff with real archives and checksum failures."""
import pathlib
import subprocess
import tempfile

SCRIPT = pathlib.Path(__file__).resolve().with_name("source-artifact.sh")


def run(*args, cwd=None, success=True):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if (result.returncode == 0) != success:
        raise AssertionError(f"{args}: {result.stdout}{result.stderr}")


with tempfile.TemporaryDirectory(prefix="mojotui-artifact-test-") as folder:
    root = pathlib.Path(folder)
    repo, archives, restored = (root / name for name in ("repo", "archives", "restored"))
    repo.mkdir()
    for name in ("pixi.toml", "pixi.lock", "mojotui/__init__.mojo", "conda.recipe/recipe.yaml", "conda.recipe/test_package.mojo"):
        path = repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"fixture for {name}\n")
    run("git", "init", "--quiet", cwd=repo)
    run("git", "add", ".", cwd=repo)
    run("git", "-c", "user.name=Artifact test", "-c", "user.email=test@example.invalid",
        "commit", "--quiet", "-m", "fixture", cwd=repo)
    run("bash", str(SCRIPT), "create", "HEAD", "mojotui-test", str(archives), cwd=repo)
    run("bash", str(SCRIPT), "restore", "mojotui-test", str(archives), str(restored))
    assert not (restored / ".git").exists()
    assert (restored / "pixi.lock").read_bytes() == (repo / "pixi.lock").read_bytes()
    stale = restored / "stale.mojo"
    stale.write_text("preserve caller-owned files")
    run("bash", str(SCRIPT), "restore", "mojotui-test", str(archives), str(restored), success=False)
    assert stale.read_text() == "preserve caller-owned files"
    run("bash", str(SCRIPT), "restore", "../invalid", str(archives), str(restored), success=False)
    archive = archives / "mojotui-test.tar.gz"
    archive.write_bytes(archive.read_bytes() + b"corrupt")
    rejected = root / "rejected"
    run("bash", str(SCRIPT), "restore", "mojotui-test", str(archives), str(rejected), success=False)
    assert not rejected.exists(), "checksum failure must stop before extraction"
print("source artifact tests passed (canonical contents, checksum, extraction, fresh destination, invalid input)")
