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
import json
import math
import sys
from pathlib import Path

import pandas as pd

__version__ = "0.1"

# Colour-blind friendly categorical palette (Okabe-Ito, extended), without black
# and yellow, which are hard to see on a dark or light background respectively
PALETTE = [
    "#0072B2",
    "#E69F00",
    "#009E73",
    "#CC79A7",
    "#56B4E9",
    "#D55E00",
    "#999933",
    "#AA4499",
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

EVALUATION_DESCRIPTION = (
    "Estimated proportions of each reference-based tool compared with the expected "
    "proportions (ground truth). The metrics are computed over all the cell types "
    "of the samples present in both: mean squared error (MSE), root mean squared "
    "error (RMSE) and Spearman correlation. Tools are sorted by RMSE (best first)."
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
        "--ground_truth",
        help=(
            "Expected cell type proportions of the bulk samples (CSV): a 'sample' "
            "column followed by one column per cell type of the reference."
        ),
    )
    parser.add_argument(
        "--metrics",
        default="evaluation_metrics.csv",
        help=(
            "Output CSV with the evaluation metrics of each tool, written when "
            "--ground_truth is given (default: evaluation_metrics.csv)."
        ),
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


def read_ground_truth(path):
    """Read the expected proportions, indexed by sample, or exit with an error."""
    truth = pd.read_csv(path)
    if truth.columns[0] != "sample":
        sys.exit(f"Error: the first column of {path} must be named 'sample'.")
    truth = truth.set_index("sample").apply(pd.to_numeric, errors="coerce")
    if truth.isnull().values.any():
        sys.exit(f"Error: {path} contains missing or non-numeric proportions.")
    if (truth.values < 0).any() or (truth.values > 1).any():
        sys.exit(
            f"Error: the proportions in {path} must be between 0 and 1 "
            "(percentages are not supported)."
        )
    return truth


def evaluate(df, truth):
    """Compare the estimates of each tool with the expected proportions.

    Returns the metrics of each tool (sorted by RMSE) and, for each tool, the
    table of predicted and expected values of every sample and cell type.
    """
    cell_types = [c for c in truth.columns if c in df.columns]
    metrics = []
    values = {}
    for tool, rows in df.groupby("tool", sort=False):
        predicted = rows.set_index("sample")[cell_types]
        samples = predicted.index.intersection(truth.index)
        pairs = (
            pd.DataFrame(
                {
                    "predicted": predicted.loc[samples].stack(),
                    "expected": truth.loc[samples, cell_types].stack(),
                }
            )
            .dropna()
            .rename_axis(["sample", "cell_type"])
            .reset_index()
        )
        if pairs.empty:
            continue
        mse = ((pairs["predicted"] - pairs["expected"]) ** 2).mean()
        metrics.append(
            {
                "tool": tool,
                "samples": len(samples),
                "MSE": mse,
                "RMSE": math.sqrt(mse),
                "Spearman": pairs["predicted"].corr(
                    pairs["expected"], method="spearman"
                ),
            }
        )
        values[tool] = pairs

    columns = ["tool", "samples", "MSE", "RMSE", "Spearman"]
    metrics = pd.DataFrame(metrics, columns=columns).sort_values("RMSE")
    return metrics.reset_index(drop=True), values


def checkbox_list(group, title, names, colors):
    """Return a list of checkboxes (all selected) to filter the explorer plot."""
    boxes = "".join(
        f'<label><input type="checkbox" data-group="{group}" '
        f'value="{html.escape(str(name))}" checked>'
        f'<span class="swatch" style="background:{colors[name]}"></span>'
        f"{html.escape(str(name))}</label>"
        for name in names
    )
    return (
        f'<fieldset><legend>{title}</legend><div class="select-buttons">'
        f'<button type="button" data-group="{group}" data-select="all">All</button>'
        f'<button type="button" data-group="{group}" data-select="none">None</button>'
        f'</div><div class="choices">{boxes}</div></fieldset>'
    )


def explorer(values, tools, cell_types, cell_colors):
    """Return the interactive plot of the predicted vs expected proportions.

    A single scatter plot where the tools and cell types to show can be selected,
    with the points coloured by tool or by cell type, and the metrics of the
    selected points recomputed in the browser (see EXPLORER_SCRIPT).
    """
    tool_colors = {tool: PALETTE[i % len(PALETTE)] for i, tool in enumerate(tools)}
    points = [
        {
            "tool": tool,
            "sample": str(row.sample),
            "cell_type": str(row.cell_type),
            "predicted": float(row.predicted),
            "expected": float(row.expected),
        }
        for tool in tools
        for row in values[tool].itertuples()
    ]
    # Same axes whatever the selection, so that plots stay comparable
    low = min([0.0] + [p["predicted"] for p in points])
    high = max([1.0] + [max(p["predicted"], p["expected"]) for p in points])
    data = {
        "points": points,
        "range": [low, high],
        "colors": {"tool": tool_colors, "cell_type": cell_colors},
    }
    # Escape '</' so that the JSON cannot close the <script> element
    payload = json.dumps(data).replace("</", "<\\/")

    return (
        '<div id="explorer" class="explorer">'
        '<div class="explorer-controls">'
        f"{checkbox_list('tool', 'Tools', tools, tool_colors)}"
        f"{checkbox_list('cell_type', 'Cell types', cell_types, cell_colors)}"
        '<fieldset><legend>Colour by</legend><div class="choices">'
        '<label><input type="radio" name="colour-by" value="tool" checked>tool'
        "</label>"
        '<label><input type="radio" name="colour-by" value="cell_type">cell type'
        "</label></div></fieldset>"
        "</div>"
        '<div class="explorer-plot-area">'
        '<p class="explorer-stats"></p>'
        '<svg class="explorer-plot" viewBox="0 0 470 470" role="img" '
        'aria-label="Predicted vs expected proportions"></svg>'
        '<div class="legend explorer-legend"></div>'
        "</div>"
        f'<script type="application/json" id="explorer-data">{payload}</script>'
        f"<script>{EXPLORER_SCRIPT}</script>"
        "</div>"
    )


def evaluation_section(df, truth, colors, metrics, values):
    """Return the report section with the evaluation against the ground truth."""
    notes = []
    no_truth = sorted(set(df["sample"]) - set(truth.index))
    if no_truth:
        notes.append(
            "Samples without expected proportions, not evaluated: "
            + ", ".join(html.escape(str(s)) for s in no_truth)
            + "."
        )
    no_results = sorted(set(truth.index) - set(df["sample"]))
    if no_results:
        notes.append(
            "Samples of the ground truth without results: "
            + ", ".join(html.escape(str(s)) for s in no_results)
            + "."
        )
    notes_html = "".join(f'<p class="note">{note}</p>' for note in notes)

    if metrics.empty:
        cards = [
            '<article class="card"><p class="note">No sample of the ground truth '
            "was found in the results, so no tool could be evaluated.</p></article>"
        ]
        return section(
            "evaluation",
            "Evaluation against ground truth",
            EVALUATION_DESCRIPTION,
            [notes_html] + cards,
        )

    summary = (
        '<article class="card">'
        f"{notes_html}{html_metrics_table(metrics)}"
        "<h3>Predicted vs expected proportions</h3>"
        '<p class="note">Select the tools and cell types to show. The metrics '
        "above the plot are computed on the selected points only. Hover a point "
        "to see its values; points on the dashed line are perfect predictions.</p>"
        f"{explorer(values, list(metrics['tool']), list(truth.columns), colors)}"
        "</article>"
    )
    return section(
        "evaluation",
        "Evaluation against ground truth",
        EVALUATION_DESCRIPTION,
        [summary],
    )


def html_metrics_table(metrics):
    """Return the metrics as an HTML table, marking the best value of each column."""
    best = {
        "MSE": metrics["MSE"].min(),
        "RMSE": metrics["RMSE"].min(),
        "Spearman": metrics["Spearman"].max(),
    }
    header = "".join(f"<th>{col}</th>" for col in metrics.columns)
    rows = []
    for row in metrics.itertuples(index=False):
        cells = [f"<th>{html.escape(str(row.tool))}</th>", f"<td>{row.samples}</td>"]
        for col, digits in (("MSE", 4), ("RMSE", 3), ("Spearman", 3)):
            value = getattr(row, col)
            text = "&ndash;" if pd.isna(value) else f"{value:.{digits}f}"
            mark = ' class="best"' if not pd.isna(value) and value == best[col] else ""
            cells.append(f"<td{mark}>{text}</td>")
        rows.append(f"<tr>{''.join(cells)}</tr>")
    return (
        f'<div class="scroll"><table><thead><tr>{header}</tr></thead>'
        f"<tbody>{''.join(rows)}</tbody></table></div>"
    )


def build_report(paths, pipeline_version, ground_truth=None, metrics_file=None):
    """Return the full HTML report."""
    results = {key: [] for key in SECTIONS}
    for path in paths:
        results[section_key(path)].append(read_results(path))

    sections = []
    nav = []

    # Evaluation of the reference-based tools against the expected proportions
    if ground_truth and results["refbased"]:
        df = pd.concat([df for df, _ in results["refbased"]], ignore_index=True)
        truth = read_ground_truth(ground_truth)
        # Same colours as in the rest of the report (order of the results columns)
        components = list(
            dict.fromkeys(c for _, comps in results["refbased"] for c in comps)
        )
        colors = component_colors(components)
        metrics, values = evaluate(df, truth)
        metrics.to_csv(metrics_file, index=False)
        sections.append(evaluation_section(df, truth, colors, metrics, values))
        nav.append(nav_links("Evaluation", [("evaluation", "metrics per tool")]))

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
td.best { font-weight: 700; color: var(--accent); }
.explorer {
  display: grid; grid-template-columns: minmax(170px, 220px) 1fr; gap: 16px;
  margin-top: 8px;
}
@media (max-width: 640px) { .explorer { grid-template-columns: 1fr; } }
.explorer fieldset {
  border: 1px solid var(--border); border-radius: 6px; margin: 0 0 10px;
  padding: 6px 10px 8px;
}
.explorer legend { font-weight: 600; font-size: 13px; padding: 0 4px; }
.explorer .choices { display: flex; flex-direction: column; gap: 3px; }
.explorer label {
  display: flex; align-items: center; gap: 6px; font-size: 13px; cursor: pointer;
}
.select-buttons { display: flex; gap: 6px; margin: 2px 0 6px; }
.select-buttons button {
  font: inherit; font-size: 12px; padding: 1px 10px; cursor: pointer;
  border: 1px solid var(--border); border-radius: 4px; background: var(--bg);
  color: var(--text);
}
.explorer-stats { margin: 0 0 6px; font-size: 14px; }
.explorer-plot { width: 100%; max-width: 520px; height: auto; display: block; }
.explorer-plot .frame { fill: none; stroke: var(--border); }
.explorer-plot .grid { stroke: var(--border); stroke-width: 0.6; }
.explorer-plot .diagonal { stroke: var(--muted); stroke-dasharray: 5 4; }
.explorer-plot .axis { text-anchor: middle; font-size: 13px; fill: var(--muted); }
.explorer-plot .tick { text-anchor: middle; font-size: 11px; fill: var(--muted); }
.explorer-plot .tick.end { text-anchor: end; }
.explorer-plot circle { stroke: var(--card); stroke-width: 1; opacity: 0.9; }
.explorer-plot .empty { text-anchor: middle; font-size: 14px; fill: var(--muted); }
th, td { padding: 4px 10px; border-bottom: 1px solid var(--border); text-align: right; }
th:first-child { text-align: left; }
"""


# Draws the explorer plot in the browser from the JSON data embedded in the report.
# The Spearman correlation uses average ranks for ties, as pandas does.
EXPLORER_SCRIPT = r"""
(function () {
  var root = document.getElementById("explorer");
  if (!root) { return; }
  var data = JSON.parse(document.getElementById("explorer-data").textContent);
  var svg = root.querySelector(".explorer-plot");
  var NS = "http://www.w3.org/2000/svg";
  var size = 400, left = 56, top = 10;
  var low = data.range[0], high = data.range[1];

  function sx(v) { return left + (v - low) / (high - low) * size; }
  function sy(v) { return top + size - (v - low) / (high - low) * size; }

  function element(name, attributes, text) {
    var node = document.createElementNS(NS, name);
    for (var key in attributes) { node.setAttribute(key, attributes[key]); }
    if (text !== undefined) { node.textContent = text; }
    return node;
  }

  function add(name, attributes, text) {
    return svg.appendChild(element(name, attributes, text));
  }

  function selected(group) {
    var values = {};
    root.querySelectorAll('input[data-group="' + group + '"]').forEach(function (box) {
      if (box.checked) { values[box.value] = true; }
    });
    return values;
  }

  function ranks(values) {
    var order = values.map(function (v, i) { return i; })
      .sort(function (a, b) { return values[a] - values[b]; });
    var result = new Array(values.length);
    for (var i = 0; i < order.length;) {
      var j = i;
      while (j + 1 < order.length && values[order[j + 1]] === values[order[i]]) { j++; }
      for (var k = i; k <= j; k++) { result[order[k]] = (i + j) / 2 + 1; }
      i = j + 1;
    }
    return result;
  }

  function pearson(a, b) {
    var n = a.length, ma = 0, mb = 0, cov = 0, va = 0, vb = 0;
    for (var i = 0; i < n; i++) { ma += a[i] / n; mb += b[i] / n; }
    for (i = 0; i < n; i++) {
      cov += (a[i] - ma) * (b[i] - mb);
      va += (a[i] - ma) * (a[i] - ma);
      vb += (b[i] - mb) * (b[i] - mb);
    }
    return va > 0 && vb > 0 ? cov / Math.sqrt(va * vb) : NaN;
  }

  function format(value, digits) {
    return isNaN(value) ? "–" : value.toFixed(digits);
  }

  function drawAxes() {
    var bottom = top + size, middle = top + size / 2;
    add("rect", { x: left, y: top, width: size, height: size, "class": "frame" });
    for (var t = Math.ceil(low * 4) / 4; t <= high + 1e-9; t += 0.25) {
      var label = String(+t.toFixed(2));
      add("line", { x1: sx(t), y1: top, x2: sx(t), y2: bottom, "class": "grid" });
      add("line", { x1: left, y1: sy(t), x2: left + size, y2: sy(t), "class": "grid" });
      add("text", { x: sx(t), y: bottom + 16, "class": "tick" }, label);
      add("text", { x: left - 6, y: sy(t) + 4, "class": "tick end" }, label);
    }
    add("line", { x1: sx(low), y1: sy(low), x2: sx(high), y2: sy(high),
      "class": "diagonal" });
    add("text", { x: left + size / 2, y: bottom + 40, "class": "axis" },
      "expected proportion");
    add("text", { x: 16, y: middle, "class": "axis",
      transform: "rotate(-90 16 " + middle + ")" }, "predicted proportion");
  }

  function draw() {
    var tools = selected("tool"), cellTypes = selected("cell_type");
    var colourBy = root.querySelector('input[name="colour-by"]:checked').value;
    var colors = data.colors[colourBy];
    var points = data.points.filter(function (p) {
      return tools[p.tool] && cellTypes[p.cell_type];
    });

    while (svg.lastChild) { svg.removeChild(svg.lastChild); }
    drawAxes();
    points.forEach(function (p) {
      var dot = add("circle", { cx: sx(p.expected), cy: sy(p.predicted), r: 5,
        fill: colors[p[colourBy]] });
      dot.appendChild(element("title", {},
        p.tool + " · " + p.sample + " · " + p.cell_type +
        "\npredicted " + p.predicted.toFixed(3) +
        ", expected " + p.expected.toFixed(3)));
    });
    if (!points.length) {
      add("text", { x: left + size / 2, y: top + size / 2, "class": "empty" },
        "Select at least one tool and one cell type");
    }

    // Metrics of the selected points
    var stats = root.querySelector(".explorer-stats");
    if (points.length) {
      var predicted = points.map(function (p) { return p.predicted; });
      var expected = points.map(function (p) { return p.expected; });
      var mse = 0;
      for (var i = 0; i < points.length; i++) {
        mse += Math.pow(predicted[i] - expected[i], 2) / points.length;
      }
      stats.textContent = points.length + " points · MSE " + format(mse, 4) +
        " · RMSE " + format(Math.sqrt(mse), 3) +
        " · Spearman " + format(pearson(ranks(predicted), ranks(expected)), 3);
    } else {
      stats.textContent = "No points selected";
    }

    // Legend of the colours used
    var legend = root.querySelector(".explorer-legend");
    legend.textContent = "";
    var shown = {};
    points.forEach(function (p) { shown[p[colourBy]] = true; });
    Object.keys(colors).forEach(function (name) {
      if (!shown[name]) { return; }
      var key = document.createElement("span");
      key.className = "key";
      var swatch = document.createElement("span");
      swatch.className = "swatch";
      swatch.style.background = colors[name];
      key.appendChild(swatch);
      key.appendChild(document.createTextNode(name));
      legend.appendChild(key);
    });
  }

  root.addEventListener("change", draw);
  root.querySelectorAll("button[data-select]").forEach(function (button) {
    button.addEventListener("click", function () {
      var on = button.getAttribute("data-select") === "all";
      var group = button.getAttribute("data-group");
      root.querySelectorAll('input[data-group="' + group + '"]')
        .forEach(function (box) { box.checked = on; });
      draw();
    });
  });
  draw();
})();
"""


def main():
    args = parse_arguments()
    report = build_report(
        args.results, args.pipeline_version, args.ground_truth, args.metrics
    )
    Path(args.outfile).write_text(report, encoding="utf-8")


if __name__ == "__main__":
    main()
