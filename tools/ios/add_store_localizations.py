#!/usr/bin/env python3
"""Put en/de/fr/es/pt .lproj folders into a Godot iOS export.

App Store Connect lists languages from .lproj directories inside the .app.
Godot 4.6 writes those only when Project Settings registers translation
resources. Oil Due loads translations/oil_due.csv itself, so the export
otherwise ships the template's en.lproj and the store says English only.

The app name stays "Oil Due" in every language.
"""

from __future__ import annotations

import re
import sys
import tempfile
from pathlib import Path


LOCALES = ("en", "de", "fr", "es", "pt")
EXTRA_LOCALES = ("de", "fr", "es", "pt")
APP_NAME = "Oil Due"
FILE_IDS = {
	"de": "D0BCFE4518AEBDA2004A0001",
	"fr": "D0BCFE4518AEBDA2004A0002",
	"es": "D0BCFE4518AEBDA2004A0003",
	"pt": "D0BCFE4518AEBDA2004A0004",
}
STRINGS = (
	"/* Localized versions of Info.plist keys */\n"
	"\n"
	'CFBundleDisplayName = "Oil Due";\n'
	'CFBundleName = "Oil Due";\n'
)
ANSI = re.compile(r"\x1b\[[0-9;]*m")
PACKED = re.compile(r"Storing File: (res://translations/oil_due\S*)")


def strings_text() -> str:
	if "ja" in STRINGS.lower() or APP_NAME != "Oil Due":
		raise RuntimeError("localization strings drifted")
	return STRINGS


def write_lproj(app_src: Path) -> None:
	text = strings_text()
	for lang in LOCALES:
		folder = app_src / f"{lang}.lproj"
		folder.mkdir(parents=True, exist_ok=True)
		(folder / "InfoPlist.strings").write_text(text, encoding="utf-8")
		ja = app_src / "ja.lproj"
		if ja.exists():
			raise SystemExit(f"refusing to leave {ja} in the export")


def _file_ref_id(text: str, lang: str) -> str:
	match = re.search(
		rf'([A-F0-9]{{24}}) /\* {lang} \*/ = \{{isa = PBXFileReference;[^}}]*path = {lang}\.lproj/InfoPlist\.strings;',
		text,
	)
	return match.group(1) if match else ""


def _insert_after(text: str, pattern: str, addition: str) -> str:
	match = re.search(pattern, text, re.M)
	if not match:
		raise SystemExit(f"pbxproj is missing expected line: {pattern}")
	at = match.end()
	if text[at:at + 1] == "\n":
		at += 1
	return text[:at] + addition + text[at:]


def patch_pbxproj(text: str) -> str:
	en_line = re.search(
		r"^(\t*)([A-F0-9]{24}) /\* en \*/ = \{isa = PBXFileReference;[^}]*path = en\.lproj/InfoPlist\.strings;.*\};\s*$",
		text,
		re.M,
	)
	if not en_line:
		raise SystemExit("pbxproj has no en.lproj/InfoPlist.strings file reference")
	indent = en_line.group(1)
	for lang in EXTRA_LOCALES:
		if _file_ref_id(text, lang):
			continue
		file_id = FILE_IDS[lang]
		line = (
			f"{indent}{file_id} /* {lang} */ = {{isa = PBXFileReference; "
			f"lastKnownFileType = text.plist.strings; name = {lang}; "
			f'path = {lang}.lproj/InfoPlist.strings; sourceTree = "<group>"; }};\n'
		)
		text = _insert_after(text, re.escape(en_line.group(0)), line)
		en_line = re.search(re.escape(en_line.group(0)), text)
		if en_line is None:
			raise SystemExit("lost the en file reference while patching")

	variant = re.search(
		r"(/\* Begin PBXVariantGroup section \*/.*?/\* End PBXVariantGroup section \*/)",
		text,
		re.S,
	)
	if not variant:
		raise SystemExit("pbxproj has no PBXVariantGroup for InfoPlist.strings")
	block = variant.group(1)
	updated = block
	for lang in EXTRA_LOCALES:
		file_id = _file_ref_id(text, lang)
		if not file_id:
			raise SystemExit(f"no file reference for {lang}.lproj after patching")
		if re.search(rf"{file_id} /\* {lang} \*/", updated):
			continue
		child = f"\t\t\t\t{file_id} /* {lang} */,\n"
		marker = re.search(r"(/\* en \*/,)\n", updated)
		if not marker:
			raise SystemExit("variant group has no en child")
		updated = updated[: marker.end()] + child + updated[marker.end() :]
	text = text[: variant.start(1)] + updated + text[variant.end(1) :]

	regions = re.search(r"knownRegions = \((.*?)\);", text, re.S)
	if not regions:
		raise SystemExit("pbxproj has no knownRegions")
	body = regions.group(1)
	lines = body.splitlines()
	present = set()
	indent = "\t\t\t\t"
	for line in lines:
		entry = re.match(r"(\s*)([A-Za-z0-9]+)\s*,\s*$", line)
		if entry:
			present.add(entry.group(2))
			if entry.group(2) == "Base":
				indent = entry.group(1)
	extra = [f"{indent}{lang}," for lang in LOCALES if lang not in present]
	if extra:
		rebuilt: list[str] = []
		inserted = False
		for line in lines:
			rebuilt.append(line)
			if re.match(r"\s*Base\s*,\s*$", line):
				rebuilt.extend(extra)
				inserted = True
		if not inserted:
			raise SystemExit("knownRegions has no Base")
		text = text[: regions.start(1)] + "\n".join(rebuilt) + text[regions.end(1) :]
	return text


def app_source(pbx: Path) -> Path:
	project_dir = pbx.parent.parent
	name = pbx.parent.name.removesuffix(".xcodeproj")
	candidate = project_dir / name
	if (candidate / "en.lproj").is_dir() or candidate.is_dir():
		return candidate
	matches = [p.parent for p in project_dir.glob("*/en.lproj")]
	if len(matches) == 1:
		return matches[0]
	raise SystemExit(f"could not find the app source next to {pbx}")


def localize_tree(root: Path) -> int:
	projects = [
		pbx
		for pbx in root.rglob("project.pbxproj")
		if "Pods" not in pbx.parts and pbx.parent.suffix == ".xcodeproj"
	]
	if not projects:
		raise SystemExit(f"no .xcodeproj under {root}")
	changed = 0
	for pbx in projects:
		src = app_source(pbx)
		write_lproj(src)
		original = pbx.read_text(encoding="utf-8")
		updated = patch_pbxproj(original)
		if updated != original:
			pbx.write_text(updated, encoding="utf-8")
			changed += 1
			print(f"Added de/fr/es/pt InfoPlist.strings in {pbx}")
		else:
			print(f"Localizations already present in {pbx}")
		print(f"Wrote {', '.join(lang + '.lproj' for lang in LOCALES)} under {src}")
	return changed


def export_log_error(log: str) -> str:
	paths = PACKED.findall(ANSI.sub("", log))
	if "res://translations/oil_due.csv" not in paths:
		return f"iOS export did not pack res://translations/oil_due.csv (packed {paths})"
	translated = [path for path in paths if path.endswith(".translation")]
	if translated:
		return f"iOS export packed .translation files the runtime loader does not open: {translated}"
	return ""


def pck_error(data: bytes) -> str:
	if b"translations/oil_due.csv" not in data:
		return "app pack has no translations/oil_due.csv entry"
	if b"oil_due.fr.translation" in data or b"oil_due.de.translation" in data:
		return "app pack still contains imported .translation files"
	return ""


def verify_app(app: Path) -> None:
	missing = []
	for lang in LOCALES:
		path = app / f"{lang}.lproj" / "InfoPlist.strings"
		if not path.is_file():
			missing.append(str(path))
	japanese = list(app.rglob("ja.lproj"))
	if japanese:
		raise SystemExit(f"unexpected Japanese lproj: {japanese}")
	if missing:
		raise SystemExit("missing localization folders: " + ", ".join(missing))
	print(f"App bundle has {', '.join(lang + '.lproj' for lang in LOCALES)}: {app}")


def _self_test() -> int:
	snippet = """// !$*UTF8*$!
{
	objects = {
		D0BCFE4518AEBDA2004A7AAE /* en */ = {isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = en; path = en.lproj/InfoPlist.strings; sourceTree = "<group>"; };
		D0BCFE7718AEBFEB004A7AAE /* OilDue.pck */ = {isa = PBXFileReference; lastKnownFileType = file; path = "OilDue.pck"; sourceTree = "<group>"; };
			developmentRegion = en;
			knownRegions = (
				en,
				Base,
			);
/* Begin PBXVariantGroup section */
		D0BCFE4418AEBDA2004A7AAE /* InfoPlist.strings */ = {
			isa = PBXVariantGroup;
			children = (
				D0BCFE4518AEBDA2004A7AAE /* en */,
			);
			name = InfoPlist.strings;
			sourceTree = "<group>";
		};
/* End PBXVariantGroup section */
	};
}
"""
	once = patch_pbxproj(snippet)
	twice = patch_pbxproj(once)
	if once != twice:
		print("patch is not idempotent", file=sys.stderr)
		return 1
	for lang in EXTRA_LOCALES:
		if f"path = {lang}.lproj/InfoPlist.strings" not in once:
			print(f"missing file ref {lang}", file=sys.stderr)
			return 1
		if once.count(f"/* {lang} */") != 2:
			print(f"expected file ref and variant child for {lang}", file=sys.stderr)
			return 1
		if not re.search(rf"(?m)^\s*{lang}\s*,\s*$", once):
			print(f"missing knownRegions {lang}", file=sys.stderr)
			return 1
	if "ja.lproj" in once or "/* ja */" in once:
		print("japanese leaked into pbxproj", file=sys.stderr)
		return 1
	log = """
[  92% ] savepack | Storing File: res://translations/oil_due.csv
[  96% ] savepack | Storing File: res://translations/oil_due.csv.import
"""
	if export_log_error(log):
		print(export_log_error(log), file=sys.stderr)
		return 1
	bad_log = "[  94% ] savepack | Storing File: res://translations/oil_due.fr.translation\n"
	bad_log += "[  96% ] savepack | Storing File: res://translations/oil_due.csv.import\n"
	if not export_log_error(bad_log):
		print("accepted an export that dropped the CSV", file=sys.stderr)
		return 1
	with tempfile.TemporaryDirectory() as tmp:
		root = Path(tmp)
		app = root / "OilDue"
		(app / "en.lproj").mkdir(parents=True)
		(app / "en.lproj" / "InfoPlist.strings").write_text("/* old */\n", encoding="utf-8")
		proj = root / "OilDue.xcodeproj"
		proj.mkdir()
		(proj / "project.pbxproj").write_text(snippet, encoding="utf-8")
		localize_tree(root)
		verify_app(app)
		text = (app / "fr.lproj" / "InfoPlist.strings").read_text(encoding="utf-8")
		if 'CFBundleDisplayName = "Oil Due";' not in text or 'CFBundleName = "Oil Due";' not in text:
			print(text, file=sys.stderr)
			return 1
		for lang in EXTRA_LOCALES:
			same = (app / f"{lang}.lproj" / "InfoPlist.strings").read_text(encoding="utf-8")
			if same != text:
				print(f"{lang} display name differs", file=sys.stderr)
				return 1
		localize_tree(root)
		verify_app(app)
	if pck_error(b"res://translations/oil_due.csv\nAjouter un entretien"):
		print(pck_error(b"res://translations/oil_due.csv"), file=sys.stderr)
		return 1
	if not pck_error(b"res://translations/oil_due.fr.translation"):
		print("pck check missed a .translation", file=sys.stderr)
		return 1
	print("self-test ok")
	return 0


def main(argv: list[str]) -> int:
	if len(argv) == 2 and argv[1] == "--self-test":
		return _self_test()
	if len(argv) == 3 and argv[1] == "--check-export-log":
		err = export_log_error(Path(argv[2]).read_text(encoding="utf-8", errors="replace"))
		if err:
			print(err, file=sys.stderr)
			return 1
		print("Export log packs translations/oil_due.csv")
		return 0
	if len(argv) == 3 and argv[1] == "--verify-app":
		verify_app(Path(argv[2]))
		return 0
	if len(argv) == 3 and argv[1] == "--verify-pck":
		err = pck_error(Path(argv[2]).read_bytes())
		if err:
			print(err, file=sys.stderr)
			return 1
		data = Path(argv[2]).read_bytes()
		french = b"Ajouter un entretien" in data
		print(f"pck contains oil_due.csv; french source text visible: {french}")
		return 0
	if len(argv) != 2:
		print(
			"usage: add_store_localizations.py <build-root> | --self-test | --check-export-log <log> | --verify-app <App.app> | --verify-pck <file.pck>",
			file=sys.stderr,
		)
		return 1
	localize_tree(Path(argv[1]))
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv))
