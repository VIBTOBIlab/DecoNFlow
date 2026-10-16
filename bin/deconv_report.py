#!/usr/bin/env python
"""Generate an HTML report of the deconvolution results, per sample and per tool.

Each input is a combined results table produced by ``combine_files.py``: one
row per sample and tool, with the sample name in the ``sample`` column, the
tool in the ``tool`` column and one column per cell type (reference-based) or
latent component (reference-free). Files whose name contains ``reffree`` are
reported as reference-free results, the others as reference-based results.

The report starts with a per-sample comparison of the reference-based tools
(a stacked bar per tool, and the mean, SD and range of each cell type across
tools), followed by the results of each tool (a stacked bar per sample, and a
table with the exact values). The page is self-contained (no external scripts
or stylesheets), so it can be opened offline.

Author: Edoardo Giuili (edoardo.giuili@ugent.be)
"""

import argparse
import datetime
import html
from pathlib import Path

import pandas as pd

__version__ = "0.1"

# Colour-blind friendly categorical palette (Okabe-Ito, extended)
PALETTE = [
    "#0072B2",
    "#E69F00",
    "#009E73",
    "#CC79A7",
    "#56B4E9",
    "#D55E00",
    "#F0E442",
    "#000000",
    "#999999",
    "#882255",
    "#44AA99",
    "#117733",
]

SECTIONS = {
    "refbased": (
        "Reference-based deconvolution",
        "Proportions of the cell types present in the reference atlas.",
    ),
    "reffree": (
        "Reference-free deconvolution",
        "Proportions of the latent methylation components (e.g. LMC1, V1) "
        "inferred from the bulk samples. Components are not labelled with cell "
        "types and are not comparable between tools.",
    ),
}

SAMPLE_DESCRIPTION = (
    "Cell type proportions estimated by each reference-based tool for the same "
    "sample, with the mean, standard deviation (SD) and range across tools."
)
SAMPLE_REFFREE_NOTE = (
    "Reference-free tools are not included, since their components are not "
    "labelled with cell types and cannot be compared between tools."
)

# Layout of the stacked bar charts, in pixels
LABEL_WIDTH = 170
BAR_WIDTH = 520
ROW_HEIGHT = 24
BAR_HEIGHT = 16
AXIS_HEIGHT = 26


def parse_arguments():
    """Parse the command line arguments."""
    parser = argparse.ArgumentParser(
        description="Generate an HTML report of the deconvolution results."
    )
    parser.add_argument(
        "--results",
        nargs="+",
        required=True,
        help="Combined results tables (CSV) produced by combine_files.py.",
    )
    parser.add_argument(
        "-o",
        "--outfile",
        default="deconvolution_report.html",
        help="Output HTML file (default: deconvolution_report.html).",
    )
    parser.add_argument(
        "--pipeline_version",
        default="",
        help="DecoNFlow version shown in the report header.",
    )
    parser.add_argument(
        "-v", "--version", action="version", version=f"%(prog)s {__version__}"
    )
    return parser.parse_args()


def section_key(path):
    """Return the report section of a results file, based on its name."""
    return "reffree" if "reffree" in Path(path).name else "refbased"


def read_results(path):
    """Read a combined results table, with numeric proportion columns."""
    df = pd.read_csv(path)
    components = [col for col in df.columns if col not in ("sample", "tool")]
    df[components] = df[components].apply(pd.to_numeric, errors="coerce")
    return df, components


def fmt(value):
    """Format a proportion for the tables, with a dash for missing values."""
    return "&ndash;" if pd.isna(value) else f"{value:.3f}"


def bar_chart(table, colors):
    """Return an inline SVG with one stacked horizontal bar per row of *table*.

    Negative estimates are drawn as 0. The axis goes from 0 to 100%, or further
    if the proportions of a row add up to more than 1.
    """
    values = table.clip(lower=0).fillna(0)
    scale = max(1.0, values.sum(axis=1).max())
    width = LABEL_WIDTH + BAR_WIDTH + 20
    height = len(values) * ROW_HEIGHT + AXIS_HEIGHT

    parts = [
        f'<svg viewBox="0 0 {width} {height}" role="img" class="chart">',
    ]

    # Vertical grid lines and axis labels
    for i in range(5):
        fraction = scale * i / 4
        x = LABEL_WIDTH + BAR_WIDTH * i / 4
        parts.append(
            f'<line x1="{x:.1f}" y1="0" x2="{x:.1f}" y2="{height - AXIS_HEIGHT}" '
            'class="grid"/>'
            f'<text x="{x:.1f}" y="{height - 8}" class="tick">{fraction:.0%}</text>'
        )

    # One stacked bar per row (a sample, or a tool in the per-sample comparison)
    for row, (label, proportions) in enumerate(values.iterrows()):
        y = row * ROW_HEIGHT
        parts.append(
            f'<text x="{LABEL_WIDTH - 8}" y="{y + ROW_HEIGHT / 2 + 4:.1f}" '
            f'class="label">{html.escape(str(label))}</text>'
        )
        x = LABEL_WIDTH
        for component, value in proportions.items():
            segment = BAR_WIDTH * value / scale
            if segment <= 0:
                continue
            tooltip = html.escape(f"{label} - {component}: {value:.3f}")
            parts.append(
                f'<rect x="{x:.2f}" y="{y + (ROW_HEIGHT - BAR_HEIGHT) / 2:.1f}" '
                f'width="{segment:.2f}" height="{BAR_HEIGHT}" '
                f'fill="{colors[component]}"><title>{tooltip}</title></rect>'
            )
            x += segment

    parts.append("</svg>")
    return "".join(parts)


def legend(components, colors):
    """Return the colour legend of the components."""
    items = "".join(
        f'<span class="key"><span class="swatch" style="background:{colors[c]}">'
        f"</span>{html.escape(str(c))}</span>"
        for c in components
    )
    return f'<div class="legend">{items}</div>'


def html_table(table, index_name):
    """Return *table* as an HTML table, with its index as the first column."""
    header = "".join(f"<th>{html.escape(str(col))}</th>" for col in table.columns)
    rows = "".join(
        f"<tr><th>{html.escape(str(label))}</th>"
        + "".join(f"<td>{fmt(value)}</td>" for value in values)
        + "</tr>"
        for label, values in table.iterrows()
    )
    return (
        f'<div class="scroll"><table><thead><tr><th>{index_name}</th>{header}'
        f"</tr></thead><tbody>{rows}</tbody></table></div>"
    )


def collapsed(summary, content):
    """Wrap *content* in a collapsible block."""
    return f"<details><summary>{summary}</summary>{content}</details>"


def negative_note(table):
    """Return a note if the chart of *table* hides negative estimates."""
    if (table < 0).any().any():
        return '<p class="note">Negative estimates are shown as 0 in the chart.</p>'
    return ""


def tool_card(anchor, tool, df, components, colors):
    """Return the report card of one tool: its estimates for every sample."""
    table = df[df["tool"] == tool].set_index("sample")[components]
    table = table.dropna(axis=1, how="all")  # components this tool did not estimate

    return (
        f'<article class="card" id="{anchor}">'
        f"<h3>{html.escape(tool)}</h3>"
        f"{legend(table.columns, colors)}"
        f"{bar_chart(table, colors)}"
        f"{negative_note(table)}"
        f"{collapsed('Show values', html_table(table, 'sample'))}"
        "</article>"
    )


def sample_card(anchor, sample, df, components, colors):
    """Return the report card of one sample: the estimates of every tool.

    Besides the chart and the values of each tool, it summarises how much the
    tools agree with the mean, standard deviation and range of each cell type.
    """
    table = df[df["sample"] == sample].set_index("tool")[components]
    table = table.dropna(axis=1, how="all")

    stats = pd.DataFrame(
        {
            "mean": table.mean(),
            "SD": table.std(),
            "min": table.min(),
            "max": table.max(),
        }
    )

    agreement = ""
    if len(table) > 1 and stats["SD"].notna().any():
        most_variable = stats["SD"].idxmax()
        agreement = (
            f'<p class="note">{len(table)} tools. Largest disagreement between '
            f"tools: <strong>{html.escape(str(most_variable))}</strong> "
            f"(SD {stats.loc[most_variable, 'SD']:.3f}).</p>"
        )

    return (
        f'<article class="card" id="{anchor}">'
        f"<h3>{html.escape(str(sample))}</h3>"
        f"{legend(table.columns, colors)}"
        f"{bar_chart(table, colors)}"
        f"{negative_note(table)}"
        f"{agreement}"
        f"{html_table(stats, 'cell type')}"
        f"{collapsed('Show values per tool', html_table(table, 'tool'))}"
        "</article>"
    )


def component_colors(components):
    """Same colour for the same cell type / component in every chart."""
    return {c: PALETTE[i % len(PALETTE)] for i, c in enumerate(components)}


def section(anchor, title, description, cards):
    """Return a report section."""
    return (
        f'<section id="{anchor}"><h2>{title}</h2>'
        f'<p class="description">{description}</p>{"".join(cards)}</section>'
    )


def nav_links(title, links):
    """Return a line of the navigation bar, from (anchor, label) pairs."""
    items = " ".join(
        f'<a href="#{anchor}">{html.escape(str(label))}</a>' for anchor, label in links
    )
    return f"<div><strong>{title}:</strong> {items}</div>"


def build_report(paths, pipeline_version):
    """Return the full HTML report."""
    results = {key: [] for key in SECTIONS}
    for path in paths:
        results[section_key(path)].append(read_results(path))

    sections = []
    nav = []

    # Per-sample comparison of the reference-based tools, which share the
    # cell types of the reference (reference-free components are not comparable)
    if results["refbased"]:
        df = pd.concat([df for df, _ in results["refbased"]], ignore_index=True)
        components = list(
            dict.fromkeys(c for _, comps in results["refbased"] for c in comps)
        )
        colors = component_colors(components)
        samples = list(dict.fromkeys(df["sample"]))
        links = [(f"sample-{i}", sample) for i, sample in enumerate(samples)]

        description = SAMPLE_DESCRIPTION
        if results["reffree"]:
            description += " " + SAMPLE_REFFREE_NOTE
        cards = [
            sample_card(anchor, sample, df, components, colors)
            for anchor, sample in links
        ]
        sections.append(section("samples", "Per-sample comparison", description, cards))
        nav.append(nav_links("Per-sample comparison", links))

    # Per-tool results, one section per type of deconvolution
    for key, (title, description) in SECTIONS.items():
        cards = []
        links = []
        for df, components in results[key]:
            colors = component_colors(components)
            for tool in df["tool"].unique():
                anchor = f"{key}-{len(links)}"
                cards.append(tool_card(anchor, tool, df, components, colors))
                links.append((anchor, tool))
        if cards:
            sections.append(section(key, title, description, cards))
            nav.append(nav_links(title, links))

    version = f" v{html.escape(pipeline_version)}" if pipeline_version else ""
    date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DecoNFlow report</title>
<style>{STYLE}</style>
</head>
<body>
<header>
<h1>DecoNFlow deconvolution report</h1>
<p class="meta">DecoNFlow{version} &middot; generated on {date}</p>
<nav>{"".join(nav)}</nav>
</header>
<main>{"".join(sections)}</main>
</body>
</html>
"""


STYLE = """
:root {
  --bg: #f7f7f5; --card: #ffffff; --text: #1d1d1b; --muted: #5f5f5a;
  --border: #e2e2dc; --accent: #24b064;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1b1c1e; --card: #26272a; --text: #ececea; --muted: #a3a39e;
    --border: #3a3b3f; --accent: #3ccf80;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--bg); color: var(--text);
  font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}
header, main { max-width: 900px; margin: 0 auto; padding: 24px 16px; }
header { border-bottom: 3px solid var(--accent); }
h1 { margin: 0 0 4px; font-size: 26px; }
h2 { margin: 32px 0 4px; font-size: 21px; }
h3 { margin: 0 0 8px; font-size: 17px; }
.meta, .description, .note { color: var(--muted); margin: 0 0 12px; }
nav div { margin-top: 6px; }
nav a { color: var(--accent); margin-right: 10px; text-decoration: none; }
.card {
  background: var(--card); border: 1px solid var(--border); border-radius: 8px;
  padding: 16px; margin: 16px 0;
}
.legend { display: flex; flex-wrap: wrap; gap: 4px 14px; margin-bottom: 8px; }
.key { display: inline-flex; align-items: center; gap: 6px; font-size: 13px; }
.swatch { width: 12px; height: 12px; border-radius: 2px; display: inline-block; }
.chart { width: 100%; height: auto; display: block; }
.chart .label { text-anchor: end; font-size: 12px; fill: var(--text); }
.chart .tick { text-anchor: middle; font-size: 11px; fill: var(--muted); }
.chart .grid { stroke: var(--border); stroke-width: 1; }
details { margin-top: 10px; }
summary { cursor: pointer; color: var(--accent); }
.scroll { overflow-x: auto; }
table { border-collapse: collapse; margin-top: 8px; font-size: 13px; }
th, td { padding: 4px 10px; border-bottom: 1px solid var(--border); text-align: right; }
th:first-child { text-align: left; }
"""


def main():
    args = parse_arguments()
    report = build_report(args.results, args.pipeline_version)
    Path(args.outfile).write_text(report, encoding="utf-8")


if __name__ == "__main__":
    main()
