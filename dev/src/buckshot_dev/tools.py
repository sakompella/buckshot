"""Resolve external tools from environment variables with a PATH fallback."""

import os
import shutil


class ToolMissing(Exception):
    """A required external tool is neither set nor on PATH."""


def resolve(env_var: str, name: str) -> str:
    """The tool overriding ``${env_var}``, or ``name`` found on PATH."""
    value = os.environ.get(env_var)
    if value:
        return value
    found = shutil.which(name)
    if found is None:
        raise ToolMissing(f"{name} not found: set ${env_var} or put {name} on PATH")
    return found
