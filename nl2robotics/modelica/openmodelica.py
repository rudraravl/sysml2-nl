"""Headless OpenModelica compiler and simulation adapter."""

from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

from .fmu import FMUInspectionError, inspect_fmu
from .models import Diagnostic, ModelicaBuild, ModelicaFMU, ModelicaRun


_MODEL = re.compile(r"(?m)^\s*model\s+([A-Za-z][A-Za-z0-9_]*)\b")


class OpenModelicaRunner:
    """Run OpenModelica directly or through the official Docker image."""

    def __init__(self, *, backend: str = "auto", omc: str = "omc",
                 image: str = "openmodelica/openmodelica:v1.27.0-ompython",
                 timeout: int = 120, library_cache: Path | None = None):
        if backend not in {"auto", "local", "docker"}:
            raise ValueError("backend must be auto, local, or docker")
        self.backend = backend
        self.omc = omc
        self.image = image
        self.timeout = timeout
        self.library_cache = library_cache or Path(
            os.getenv(
                "OPENMODELICA_LIBRARY_CACHE",
                Path(tempfile.gettempdir()) / "nl2robotics-openmodelica-libraries",
            )
        )

    def resolved_backend(self) -> str | None:
        if self.backend in {"auto", "local"} and shutil.which(self.omc):
            return "local"
        if self.backend in {"auto", "docker"} and shutil.which("docker"):
            return "docker"
        return None

    def compile(self, code: str, *, model_name: str | None = None,
                output_dir: Path | None = None) -> ModelicaBuild:
        """Check and build a model without executing the generated binary."""
        backend = self.resolved_backend()
        try:
            name = model_name or find_model_name(code)
        except ValueError as exc:
            return ModelicaBuild(
                backend is not None,
                model_name or "",
                diagnostics=[Diagnostic("source", "error", str(exc))],
            )
        if not backend:
            return ModelicaBuild(False, name, diagnostics=[
                Diagnostic("infrastructure", "error", "OpenModelica is unavailable")
            ])
        work = output_dir or Path(tempfile.mkdtemp(prefix="modelica-build-"))
        work.mkdir(parents=True, exist_ok=True)
        for stale in ("load.txt", "check.txt", "build.txt", "candidate_build"):
            (work / stale).unlink(missing_ok=True)
        (work / "Candidate.mo").write_text(code, encoding="utf-8")
        (work / "build.mos").write_text(_build_script(name), encoding="utf-8")
        started = time.monotonic()
        try:
            proc = subprocess.run(
                self._command(backend, work, "build.mos"),
                cwd=work,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=self.timeout,
                env=os.environ.copy(),
            )
        except subprocess.TimeoutExpired:
            return ModelicaBuild(
                True,
                name,
                duration_seconds=time.monotonic() - started,
                diagnostics=[Diagnostic(
                    "compiler", "error",
                    f"OpenModelica build timed out after {self.timeout}s",
                )],
            )
        duration = time.monotonic() - started
        infrastructure = _infrastructure_failure(backend, proc.stdout)
        if infrastructure:
            return ModelicaBuild(
                False,
                name,
                duration_seconds=duration,
                diagnostics=[Diagnostic("infrastructure", "error", infrastructure)],
            )
        load = _read(work / "load.txt")
        check = _read(work / "check.txt")
        build = _read(work / "build.txt")
        source_parse = self._diagnose_load_failure(backend, work, load)
        combined = "\n".join((proc.stdout, load, source_parse, check, build))
        diagnostics = _diagnostics(combined)
        executable = work / "candidate_build"
        checked = "completed successfully" in check.lower() and not _has_error(check)
        compiled = (
            proc.returncode == 0
            and checked
            and executable.is_file()
            and not _has_error(build)
        )
        if not compiled and not diagnostics:
            if checked and not executable.is_file():
                message = (
                    "OpenModelica checked the equations but produced no executable; "
                    "remove unbound parameters or other non-buildable declarations"
                )
            else:
                message = (
                    build.strip() or proc.stdout.strip()
                    or "OpenModelica build failed"
                )
            diagnostics.append(Diagnostic("compiler", "error", message))
        return ModelicaBuild(
            True,
            name,
            checked=checked,
            compiled=compiled,
            executable=executable if executable.is_file() else None,
            check_message=check.strip(),
            build_message=build.strip(),
            diagnostics=diagnostics,
            duration_seconds=duration,
        )

    def run(self, code: str, *, model_name: str | None = None,
            start_time: float = 0.0, stop_time: float = 5.0,
            intervals: int = 500, tolerance: float = 1e-6,
            solver: str = "dassl",
            output_dir: Path | None = None) -> ModelicaRun:
        backend = self.resolved_backend()
        name = model_name or find_model_name(code)
        if not backend:
            return ModelicaRun(False, name, diagnostics=[
                Diagnostic("infrastructure", "error", "OpenModelica is unavailable")
            ])
        work = output_dir or Path(tempfile.mkdtemp(prefix="modelica-run-"))
        work.mkdir(parents=True, exist_ok=True)
        for stale in ("load.txt", "check.txt", "simulate.txt", "result_res.csv"):
            (work / stale).unlink(missing_ok=True)
        (work / "Candidate.mo").write_text(code, encoding="utf-8")
        (work / "run.mos").write_text(
            _script(name, start_time, stop_time, intervals, tolerance, solver),
            encoding="utf-8",
        )
        command = self._command(backend, work, "run.mos")
        started = time.monotonic()
        try:
            proc = subprocess.run(
                command,
                cwd=work,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=self.timeout,
                env=os.environ.copy(),
            )
        except subprocess.TimeoutExpired:
            return ModelicaRun(
                True, name, duration_seconds=time.monotonic() - started,
                diagnostics=[Diagnostic("simulation", "error",
                                        f"OpenModelica timed out after {self.timeout}s")],
            )
        duration = time.monotonic() - started
        infrastructure = _infrastructure_failure(backend, proc.stdout)
        if infrastructure:
            return ModelicaRun(
                False,
                name,
                duration_seconds=duration,
                diagnostics=[Diagnostic("infrastructure", "error", infrastructure)],
            )
        load = _read(work / "load.txt")
        check = _read(work / "check.txt")
        simulation = _read(work / "simulate.txt")
        source_parse = self._diagnose_load_failure(backend, work, load)
        combined = "\n".join((proc.stdout, load, source_parse, check, simulation))
        diagnostics = _diagnostics(combined)
        result = work / "result_res.csv"
        checked = "completed successfully" in check.lower() and not _has_error(check)
        compiled = checked and "failed to build model" not in combined.lower()
        simulated = proc.returncode == 0 and result.is_file() and not _has_error(simulation)
        if proc.returncode and not diagnostics:
            diagnostics.append(Diagnostic("compiler", "error", proc.stdout.strip()))
        return ModelicaRun(
            True,
            name,
            checked=checked,
            compiled=compiled,
            simulated=simulated,
            check_message=check.strip(),
            result_file=result if result.is_file() else None,
            diagnostics=diagnostics,
            duration_seconds=duration,
        )

    def export_fmu(self, code: str, *, model_name: str | None = None,
                   output_dir: Path | None = None) -> ModelicaFMU:
        """Check a model and export an FMI 2.0 Co-Simulation FMU."""
        backend = self.resolved_backend()
        try:
            name = model_name or find_model_name(code)
        except ValueError as exc:
            return ModelicaFMU(
                backend is not None,
                model_name or "",
                diagnostics=[Diagnostic("source", "error", str(exc))],
            )
        if not backend:
            return ModelicaFMU(False, name, diagnostics=[Diagnostic(
                "infrastructure", "error", "OpenModelica is unavailable"
            )])

        work = output_dir or Path(tempfile.mkdtemp(prefix="modelica-fmu-"))
        work.mkdir(parents=True, exist_ok=True)
        for stale in ("load.txt", "check.txt", "export.txt", "candidate.fmu"):
            (work / stale).unlink(missing_ok=True)
        (work / "Candidate.mo").write_text(code, encoding="utf-8")
        (work / "export.mos").write_text(_fmu_script(name), encoding="utf-8")
        started = time.monotonic()
        try:
            proc = subprocess.run(
                self._command(backend, work, "export.mos"),
                cwd=work,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=self.timeout,
                env=os.environ.copy(),
            )
        except subprocess.TimeoutExpired:
            return ModelicaFMU(
                True,
                name,
                duration_seconds=time.monotonic() - started,
                diagnostics=[Diagnostic(
                    "fmu_export", "error",
                    f"OpenModelica FMU export timed out after {self.timeout}s",
                )],
            )

        duration = time.monotonic() - started
        infrastructure = _infrastructure_failure(backend, proc.stdout)
        if infrastructure:
            return ModelicaFMU(
                False,
                name,
                duration_seconds=duration,
                diagnostics=[Diagnostic("infrastructure", "error", infrastructure)],
            )
        load = _read(work / "load.txt")
        check = _read(work / "check.txt")
        export = _read(work / "export.txt")
        source_parse = self._diagnose_load_failure(backend, work, load)
        combined = "\n".join((proc.stdout, load, source_parse, check, export))
        diagnostics = _diagnostics(combined)
        checked = "completed successfully" in check.lower() and not _has_error(check)
        fmu_path = work / "candidate.fmu"
        exported = proc.returncode == 0 and fmu_path.is_file() and not _has_error(export)
        metadata = {}
        if exported:
            try:
                metadata = inspect_fmu(fmu_path)
            except FMUInspectionError as exc:
                exported = False
                diagnostics.append(Diagnostic("fmu_inspection", "error", str(exc)))
        if exported and metadata.get("interface_type") != "co_simulation":
            exported = False
            diagnostics.append(Diagnostic(
                "fmu_inspection", "error",
                "OpenModelica did not export a Co-Simulation FMU",
            ))
        if not exported and not diagnostics:
            diagnostics.append(Diagnostic(
                "fmu_export", "error",
                export.strip() or proc.stdout.strip() or "OpenModelica FMU export failed",
            ))
        return ModelicaFMU(
            True,
            name,
            checked=checked,
            exported=exported,
            fmu_path=fmu_path if fmu_path.is_file() else None,
            fmi_version=metadata.get("fmi_version", ""),
            interface_type=metadata.get("interface_type", ""),
            model_identifier=metadata.get("model_identifier", ""),
            variables=metadata.get("variables", []),
            diagnostics=diagnostics,
            duration_seconds=duration,
        )

    def _command(self, backend: str, work: Path, script: str) -> list[str]:
        if backend == "local":
            return [self.omc, script]
        self.library_cache.mkdir(parents=True, exist_ok=True)
        return [
            "docker", "run", "--rm",
            "-v", f"{work.resolve()}:/work",
            "-v", f"{self.library_cache.resolve()}:/root/.openmodelica",
            "-w", "/work",
            self.image,
            "omc", script,
        ]

    def _diagnose_load_failure(
        self, backend: str, work: Path, load_report: str
    ) -> str:
        """Recover parser diagnostics hidden by a false scripting loadFile().

        Some OpenModelica parse failures make ``loadFile`` return false while
        ``getErrorString`` remains empty.  Replaying only the source file makes
        OMC emit the precise line/column error needed by bounded repair.
        """
        if not _load_failed(load_report):
            return ""
        try:
            proc = subprocess.run(
                self._command(backend, work, "Candidate.mo"),
                cwd=work,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=self.timeout,
                env=os.environ.copy(),
            )
        except subprocess.TimeoutExpired:
            return (
                "Error: OpenModelica source-diagnostic replay timed out after "
                f"{self.timeout}s"
            )
        detail = (proc.stdout or "").strip()
        if detail:
            return detail
        return "Error: OpenModelica loadFile returned false for Candidate.mo"


def find_model_name(code: str) -> str:
    match = _MODEL.search(code)
    if not match:
        raise ValueError("candidate must contain a top-level Modelica model")
    return match.group(1)


def _build_script(name: str) -> str:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", name):
        raise ValueError(f"invalid Modelica model name {name!r}")
    return f'''setCommandLineOptions("--std=3.6");
if not loadModel(Modelica) then
  installPackage(Modelica, "4.1.0", exactMatch=true);
  loadModel(Modelica);
end if;
writeFile("library.txt", getErrorString());
loaded := loadFile("Candidate.mo");
loadMessages := getErrorString();
writeFile("load.txt", String(loaded) + "\n" + loadMessages);
writeFile("check.txt", checkModel({name}) + "\\n" + getErrorString());
buildModel({name}, fileNamePrefix="candidate_build");
writeFile("build.txt", getErrorString());
'''


def _script(name: str, start: float, stop: float, intervals: int,
            tolerance: float, solver: str) -> str:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", name):
        raise ValueError(f"invalid Modelica model name {name!r}")
    if stop <= start or intervals < 1 or tolerance <= 0:
        raise ValueError("invalid simulation configuration")
    if not re.fullmatch(r"[A-Za-z0-9_]+", solver):
        raise ValueError(f"invalid solver name {solver!r}")
    return f'''setCommandLineOptions("--std=3.6");
if not loadModel(Modelica) then
  installPackage(Modelica, "4.1.0", exactMatch=true);
  loadModel(Modelica);
end if;
writeFile("library.txt", getErrorString());
loaded := loadFile("Candidate.mo");
loadMessages := getErrorString();
writeFile("load.txt", String(loaded) + "\n" + loadMessages);
writeFile("check.txt", checkModel({name}) + "\\n" + getErrorString());
result := simulate({name}, startTime={start}, stopTime={stop},
  numberOfIntervals={intervals}, tolerance={tolerance}, outputFormat="csv",
  method="{solver}", fileNamePrefix="result");
writeFile("simulate.txt", result.resultFile + "\\n" + result.messages
  + "\\n" + getErrorString());
'''


def _fmu_script(name: str) -> str:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", name):
        raise ValueError(f"invalid Modelica model name {name!r}")
    return f'''setCommandLineOptions("--std=3.6");
if not loadModel(Modelica) then
  installPackage(Modelica, "4.1.0", exactMatch=true);
  loadModel(Modelica);
end if;
writeFile("library.txt", getErrorString());
loaded := loadFile("Candidate.mo");
loadMessages := getErrorString();
writeFile("load.txt", String(loaded) + "\n" + loadMessages);
writeFile("check.txt", checkModel({name}) + "\\n" + getErrorString());
generated := buildModelFMU({name}, version="2.0", fmuType="cs",
  fileNamePrefix="candidate", platforms={{"static"}});
writeFile("export.txt", generated + "\\n" + getErrorString());
'''


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def _load_failed(text: str) -> bool:
    lines = text.strip().lower().splitlines()
    return bool(lines) and lines[0] == "false"


def _has_error(text: str) -> bool:
    lowered = text.lower()
    return "error:" in lowered or "failed" in lowered


def _diagnostics(text: str) -> list[Diagnostic]:
    found = []
    seen = set()
    for line in text.splitlines():
        clean = line.strip()
        lowered = clean.lower()
        if "error:" in lowered:
            severity = "error"
        elif "warning:" in lowered:
            severity = "warning"
        else:
            continue
        if clean not in seen:
            found.append(Diagnostic("compiler", severity, clean))
            seen.add(clean)
    return found


def _infrastructure_failure(backend: str, output: str) -> str | None:
    """Identify container-runtime failures separately from candidate failures."""
    if backend != "docker":
        return None
    lowered = output.lower()
    markers = (
        "cannot connect to the docker daemon",
        "permission denied while trying to connect to the docker api",
        "error during connect",
        "is the docker daemon running",
        "no such image",
        "pull access denied",
        "manifest unknown",
    )
    if not any(marker in lowered for marker in markers):
        return None
    detail = output.strip()
    return detail[-2000:] if detail else "OpenModelica Docker runtime is unavailable"
