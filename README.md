# GmxOrg #

GmxOrg is a very small program for quickly reorganizing GameMaker: Studio projects.

Essentially, instead of dragging & dropping assets around, it allows you to work with a textual format like
```
sprites:
	group1:
		sprSome
		sprOther
	sprOuter
```
which in turn means that assigning a number of sprites to a group is merely a matter of adding a "header:" before them and indenting their names by one "layer".

## Usage:
```
gmxorg myproject.project.gmx
```
Creates a `myproject.project.gmx.py` with project structure next to the project file.

```
gmxorg myproject.project.gmx.py
```
Imports project structure back to `myproject.project.gmx`.

**Note:** You should make sure that your project is saved prior or this will override your changes.