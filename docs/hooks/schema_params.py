"""MkDocs hook that renders the pipeline parameters from nextflow_schema.json.

The placeholder ``<!-- schema-parameters -->`` in ``parameters.md`` is replaced
with one table per schema section, so the parameters page is always in sync
with the schema used to validate the parameters.

Author: Edoardo Giuili (edoardo.giuili@ugent.be)
"""

import html
import json
from pathlib import Path

PLACEHOLDER = "<!-- schema-parameters -->"
SCHEMA = Path(__file__).resolve().parents[2] / "nextflow_schema.json"


def cell(text):
    """Make a text safe for a Markdown table cell."""
    return str(text).replace("|", "\\|").replace("\n", " ").strip()


def describe(spec):
    """Description of a parameter, with its help text and allowed values."""
    # Escape the schema texts, e.g. '<cell type>_meth' would be read as an HTML tag
    parts = [html.escape(spec.get("description", ""))]
    if spec.get("help_text"):
        parts.append(html.escape(spec["help_text"]))
    if spec.get("enum"):
        parts.append("Allowed values: " + ", ".join(f"`{value}`" for value in spec["enum"]))
    if spec.get("minimum") is not None:
        parts.append(f"Minimum: `{spec['minimum']}`.")
    return "<br>".join(cell(part) for part in parts if part)


def default(spec):
    """Default value of a parameter, if any."""
    if "default" not in spec:
        return ""
    value = spec["default"]
    if isinstance(value, bool):
        value = str(value).lower()
    return f"`{value}`"


def section_table(section):
    """Markdown table of the visible parameters of a schema section."""
    required = set(section.get("required", []))
    rows = [
        "| Parameter | Description | Type | Default | Required |",
        "| --- | --- | --- | --- | :---: |",
    ]
    for name, spec in section["properties"].items():
        if spec.get("hidden"):
            continue
        rows.append(
            f"| `--{name}` | {describe(spec)} | `{spec.get('type', '')}` "
            f"| {default(spec)} | {'yes' if name in required else ''} |"
        )
    return "\n".join(rows) if len(rows) > 2 else ""


def render_schema():
    """Markdown with one heading and table per section of the schema."""
    schema = json.loads(SCHEMA.read_text())
    blocks = []
    for ref in schema["allOf"]:
        section = schema["$defs"][ref["$ref"].split("/")[-1]]
        table = section_table(section)
        if not table:
            continue
        blocks.append(f"## {section.get('title', '')}")
        if section.get("description"):
            blocks.append(section["description"])
        blocks.append(table)
    return "\n\n".join(blocks)


def on_page_markdown(markdown, page, **kwargs):
    if PLACEHOLDER in markdown:
        return markdown.replace(PLACEHOLDER, render_schema())
    return markdown
