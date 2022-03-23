package cerastes;

/**
	Resources configuration file.
	Should be modified with --macro to be sure it's correctly setup before any code is compiled.
**/
class Config {

	/**
		Map of node types for the flow editor
	**/
	public static var flowEditorNodes: Map<String, Class<Dynamic>> = [
		"Label" => Type.resolveClass("cerastes.flow.LabelNode"),
		"Scene" => Type.resolveClass("cerastes.flow.SceneNode"),
		"Exit" => Type.resolveClass("cerastes.flow.ExitNode"),
		"File" => Type.resolveClass("cerastes.flow.FileNode"),
	];
}