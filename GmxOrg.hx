package;
import haxe.io.Path;
import neko.Lib;
import sys.FileSystem;
import sys.io.File;

/**
 * https://bitbucket.org/yal_cc/gmxorg
 * @author YellowAfterlife
 */
class GmxOrg {
	static inline function error(text:String) {
		Sys.println(text);
		Sys.exit(1);
		throw text;
	}
	
	static function main() {
		var args = Sys.args();
		if (args.length < 1) {
			Sys.println("Usage:");
			Sys.println("Export: GmxOrg some.project.gmx [some.project.py]");
			Sys.println("Import: GmxOrg some.project.py [some.project.gmx]");
			return;
		}
		var pathIn:String = args[0], pathOut:String = args[1];
		if (!FileSystem.exists(pathIn)) error('`$pathIn` does not exist!');
		var export:Bool = Path.extension(pathIn) == "gmx";
		var gmxRoot:Xml;
		if (export) { // gmx ->
			if (pathOut == null) pathOut = pathIn + ".py";
			gmxRoot = Xml.parse(File.getContent(pathIn));
		} else { // -> gmx
			if (pathOut == null) pathOut = Path.withoutExtension(pathIn);
			if (!FileSystem.exists(pathOut)) error('`$pathOut` does not exist!');
			gmxRoot = Xml.parse(File.getContent(pathOut));
		}
		var gmxAssets = gmxRoot.elementsNamed("assets").next();
		/// "dir\name.ext" -> "name"
		function id(s:String):String {
			var i = s.lastIndexOf("\\");
			if (i >= 0) s = s.substring(i + 1);
			i = s.indexOf(".");
			if (i >= 0) s = s.substring(0, i);
			return s;
		}
		var kinds = ["sounds", "sprites", "backgrounds", "paths", "scripts",
			"fonts", "timelines", "objects", "rooms"];
		if (export) {
			var buf = new OrgBuf();
			buf.add("# gmxorg");
			for (kind in kinds) {
				function proc(xml:Xml) {
					if (xml.nodeName == kind) {
						buf.push(xml.get("name"));
						for (q in xml.elements()) proc(q);
						buf.pop();
					} else {
						buf.addItem(id(xml.firstChild().toString()));
					}
				}
				for (typeRoot in gmxAssets.elementsNamed(kind)) {
					buf.push(typeRoot.nodeName);
					for (q in typeRoot.elements()) proc(q);
					buf.pop();
				}
			}
			File.saveContent(pathOut, buf.toString());
		} // if (export)
		else {
			var text = File.getContent(pathIn);
			var pos = 0, len = text.length;
			var indent = 0, current = 0;
			var line = 1, lineStart = 0;
			inline function errorAt(text:String, p:Int) {
				error('$line:${p-lineStart+1} $text');
			}
			var node:Xml = null, next:Xml;
			var nodeList:Array<Xml> = null, nodeMap:Map<String, Xml> = null;
			var nodeSingle:String = null, nodePlural:String = null;
			function proc(xml:Xml) {
				if (xml.nodeName == nodePlural) {
					for (q in xml.elements()) proc(q);
				} else {
					nodeList.push(xml);
					nodeMap.set(id(xml.firstChild().toString()), xml);
				}
			}
			var sepi:Int, sepr:String;
			inline function nodeSep(target:Xml) {
				sepr = "\r\n  ";
				sepi = current;
				while (--sepi >= 0) {
					sepr += "  ";
				}
				target.addChild(Xml.createPCData(sepr));
			}
			while (pos < len) {
				var char = text.charCodeAt(pos++);
				switch (char) {
					case "\t".code: indent += 1;
					case "#".code: { // comment
						while (pos < len) {
							if (text.charCodeAt(pos) == "\n".code) {
								break;
							} else pos += 1;
						}
					};
					case "\n".code: { // linebreak
						indent = 0;
						line += 1;
						lineStart = pos;
					};
					default: { // text!
						var start = pos - 1;
						var last = char;
						while (pos < len) {
							char = text.charCodeAt(pos);
							switch (char) {
								case "\n".code, "#".code: break;
								default: last = char; pos += 1;
							}
						}
						var name = text.substring(start, pos);
						if (current > indent) {
							var itill = indent;
							if (itill < 1) itill = 1;
							while (current > itill) {
								current -= 1;
								nodeSep(node);
								node = node.parent;	
							}
							if (current > indent) { // dump uncategorized assets into `todo` folder.
								if (nodeList.length > 0) {
									next = Xml.createElement(nodePlural);
									next.set("name", "todo");
									current += 1;
									for (q in nodeList) {
										nodeSep(next);
										next.addChild(q);
									}
									current -= 1;
									nodeSep(next);
									nodeSep(node);
									node.addChild(next);
								}
								current -= 1;
								nodeSep(node);
							}
						}
						if (last == ":".code) {
							name = name.substr(0, name.length - 1);
							if (current == 0) {
								// it's a new top-level node, prepare the data.
								node = gmxAssets.elementsNamed(name).next();
								nodeList = [];
								nodeMap = new Map();
								nodePlural = name;
								nodeSingle = name.substr(0, name.length - 1);
								for (q in node.elements()) proc(q);
								// an iterator wouldn't remove all the nodes in one pass, so:
								var children = [for (q in node) q];
								while (children.length > 0) node.removeChild(children.pop());
							} else {
								nodeSep(node);
								next = Xml.createElement(nodePlural);
								next.set("name", name);
								node.addChild(next);
								node = next;
							}
							current += 1;
						} else if (current < indent) {
							// detecting missing ":", basically.
							errorAt('Unexpected indent ($indent>$current).', start);
						} else {
							// find the element, add it if found.
							next = nodeMap.get(name);
							if (next != null) {
								nodeSep(node);
								node.addChild(next);
								nodeList.remove(next);
								nodeMap.remove(name);
							}
						}
					}; // default
				} // switch (char)
			} // while (pos < len)
			File.saveContent(pathOut, gmxRoot.toString());
		} // if (!export)
	}
}

class OrgBuf extends StringBuf {
	public var indent:Int = 0;
	public function addLine() {
		var i = indent;
		addChar("\n".code);
		while (--i >= 0) addChar("\t".code);
	}
	public function addItem(text:String) {
		addLine();
		add(text);
	}
	public function push(text:String) {
		addLine();
		add(text);
		addChar(":".code);
		indent += 1;
	}
	public function pop() {
		indent -= 1;
	}
}
