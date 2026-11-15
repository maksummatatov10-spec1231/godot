"""Register enabled extension resources before first import, using Godot's generated cache."""
from pathlib import Path


def prepare_extensions(project):
    project = Path(project)
    resources = []
    for path in project.rglob("*.gdextension"):
        relative = path.relative_to(project)
        if ".godot" in relative.parts:
            continue
        if "\n" in str(relative) or "\r" in str(relative):
            raise RuntimeError("invalid newline in GDExtension resource path")
        resources.append("res://" + relative.as_posix())
    destination = project / ".godot/extension_list.cfg"
    destination.parent.mkdir(parents=True, exist_ok=True)
    contents = "".join(resource + "\n" for resource in sorted(resources))
    if not destination.exists() or destination.read_text() != contents:
        destination.write_text(contents)
