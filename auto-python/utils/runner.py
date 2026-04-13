import subprocess
import logging
import shlex
from pathlib import Path

logger = logging.getLogger(__name__)


def run_cmd(cmd: str | list, log_file: Path | None = None, conda_env: str | None = None) -> int:
    """Executa um comando shell, opcionalmente dentro de um ambiente conda."""
    if conda_env:
        if isinstance(cmd, list):
            cmd = " ".join(shlex.quote(c) for c in cmd)
        cmd = f"source ~/miniconda3/etc/profile.d/conda.sh && conda activate {conda_env} && {cmd}"
        shell = True
    else:
        shell = isinstance(cmd, str)

    logger.debug(f"Executando: {cmd}")

    kwargs: dict = {"shell": shell, "text": True}

    if log_file:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        with open(log_file, "w") as lf:
            result = subprocess.run(cmd, stdout=lf, stderr=subprocess.STDOUT, **kwargs)
    else:
        result = subprocess.run(cmd, **kwargs)

    return result.returncode


class StepTracker:
    """Persiste quais etapas já foram concluídas para permitir retomada."""

    def __init__(self, outdir: str):
        self.done_file = Path(outdir) / ".steps_done"
        self.done_file.parent.mkdir(parents=True, exist_ok=True)
        self.done_file.touch(exist_ok=True)

    def is_done(self, step: str) -> bool:
        return step in self.done_file.read_text().splitlines()

    def mark_done(self, step: str) -> None:
        with open(self.done_file, "a") as f:
            f.write(f"{step}\n")

    def reset(self, step: str | None = None) -> None:
        """Remove uma etapa específica ou todas para forçar reexecução."""
        if step is None:
            self.done_file.write_text("")
            logger.info("Todas as etapas resetadas.")
        else:
            lines = [l for l in self.done_file.read_text().splitlines() if l != step]
            self.done_file.write_text("\n".join(lines) + "\n")
            logger.info(f"Etapa resetada: {step}")
