package cerastes.tools;


import haxe.EnumTools;
import haxe.macro.Context;
import h3d.Vector;
import h2d.col.Point;
import h2d.Tile;
#if hlimgui

#if macro
import haxe.macro.Expr;
using haxe.macro.Tools;
#else
import imgui.ImGui;
import hl.NativeArray;

class ImVec2Impl {
	public var x:Single;
	public var y:Single;

	public function new() { x = 0; y = 0; }
	public function set(x:Float, y:Float) {
		this.x = x;
		this.y = y;
	}
}

private class ImVec4Impl {

	public var x:Single;
	public var y:Single;
	public var z:Single;
	public var w:Single;

	public function new() { x = 0; y = 0; z = 0; w = 0; }
	public function set(x:Float, y:Float, z:Float, w:Float) {
		this.x = x;
		this.y = y;
		this.z = z;
		this.w = w;
	}
	public function setColor(c:Int) {
		this.x = (c >> 16 & 0xff) / 0xff;
		this.y = (c >> 8  & 0xff) / 0xff;
		this.z = (c       & 0xff) / 0xff;
		this.w = (c >> 24 & 0xff) / 0xff;
	}
}

@:structInit
class TimelineItem
{
	var label: String;
	var min: Float;
	var max: Float;
}


@:structInit class TimelineGroup
{
	var label: String;
	var items: Array<TimelineItem>;
}

typedef IG = ImGuiTools;
#end

class ImGuiTools {
#if !macro
	static var typeMap: Map<String,Dynamic> = [];
	static var enumMap: Map<String,Array<Dynamic>> = [];
#end

	public static macro function wref(expr:Expr, names:Array<Expr>):Expr {
		var tmps:Array<String> = [];
		var tmpDecl:Array<Expr> = [];
		var tmpAssign:Array<Expr> = [];
		for (n in names) {
			var tmpName = "__tmp_" + tmps.length;
			tmps.push(tmpName);
			tmpDecl.push(macro var $tmpName = $n);
			tmpAssign.push(macro $n = $i{tmpName});
		}
		function repl(e:Expr) {
			switch (e.expr) {
				case ECall(e, params):
					repl(e);
					for (p in params) repl(p);
				case EConst(Constant.CIdent("_")), EConst(Constant.CIdent("__")):
					e.expr = EConst(CIdent(tmps.shift()));
				case EField(e, field):
					repl(e);
				case EParenthesis(e):
					repl(e);
				case EBlock(exprs):
					for (e in exprs) repl(e);
				default:
			}
		}
		repl(expr);
		tmpDecl.push(macro var result = $e{expr});
		var result = tmpDecl.concat(tmpAssign);
		result.push(macro result);
		return macro $b{result};
	}

	#if !macro

	public static var point:ImVec2Impl = new ImVec2Impl();
	public static var point2:ImVec2Impl = new ImVec2Impl();
	public static var point3:ImVec2Impl = new ImVec2Impl();
	public static var vec:ImVec4Impl = new ImVec4Impl();
	public static var vec2:ImVec4Impl = new ImVec4Impl();
	public static var textures:Map<h3d.mat.Texture, Int> = [];

	public static function image(tile:Tile, ?scale: ImVec2, ?tint:Int, ?borderColor:Int) @:privateAccess {
		var tex = tile.getTexture();
		if( scale != null ) point.set(tile.width * scale.x, tile.height * scale.y);
		else point.set(tile.width, tile.height);
		point2.set(tile.u, tile.v);
		point3.set(tile.u2, tile.v2);
		if (tint != null) vec.setColor(tint);
		else vec.set(1,1,1,1);
		if (borderColor != null) vec2.setColor(borderColor);
		else vec2.set(1,1,1,1);
		return ImGui.image(tex, point, point2, point3, vec, vec2);
	}

	public static function imVec4ToColor( v: ImVec4 )
	{
		return 	( Math.floor( 255. * v.x ) << 16 ) |
				( Math.floor( 255. * v.y ) <<  8 ) |
				( Math.floor( 255. * v.z ) ) |
				( Math.floor( 255. * v.w ) << 25);

	}

	public static function imageButton(tile:Tile, ?size: ImVec2, framePadding:Int = -1, ?bg:Int, ?tint:Int) @:privateAccess {
		var tex = tile.getTexture();
		point.set(size.x, size.y);
		point2.set(tile.u, tile.v);
		point3.set(tile.u2, tile.v2);
		if (bg != null) vec.setColor(bg);
		else vec.set(0,0,0,0);
		if (tint != null) vec2.setColor(tint);
		else vec2.set(1,1,1,1);
		return ImGui.imageButton(tex, point, point2, point3, framePadding, vec, vec2);
	}


	public static var arrSingle4:NativeArray<Single> = new NativeArray(4);
	public static var arrSingle3:NativeArray<Single> = new NativeArray(3);
	public static var arrSingle2:NativeArray<Single> = new NativeArray(2);
	public static var arrSingle1:NativeArray<Single> = new NativeArray(1);
	public static var arrInt1:NativeArray<Int> = new NativeArray(1);
	public static var arrInt2:NativeArray<Int> = new NativeArray(2);
	public static var arrInt3:NativeArray<Int> = new NativeArray(3);
	public static var arrInt4:NativeArray<Int> = new NativeArray(4);

	public static function sliderInt(label:String, val:Int, v_min:Int, v_max:Int, format = "%d"):Int {
		var vv = arrInt1;
		vv[0]=val;
		ImGui.sliderInt(label, vv, v_min, v_max, format);
		return vv[0];
	}

	public static function getViewportDimensions()
	{
		var size = haxe.macro.Compiler.getDefine("windowSize");
        var scale = haxe.macro.Compiler.getDefine("renderScale");
        var viewportScale = 1;
		var viewportWidth = 640;
		var viewportHeight = 360;
		if( size != null )
		{
			var p = size.split("x");
			viewportWidth = Std.parseInt(p[0]);
			viewportHeight = Std.parseInt(p[1]);
		}
        if( scale != null ) viewportScale = Std.parseInt(scale);

		return
		{
			width: Math.floor( viewportWidth / viewportScale ),
			height: Math.floor( viewportHeight / viewportScale ),
			realWidth: viewportWidth,
			realHeight: viewportHeight,
			scale: viewportScale
		}
	}

	public static function posInput<T:{ x:Float, y:Float }>(label:String, target:T, format:String = "%.3f", flags:ImGuiInputTextFlags = 0) {
		var vv = arrSingle2;
		vv[0] = target.x;
		vv[1] = target.y;
		var ret = ImGui.inputFloat2(label, vv, format, flags);
		target.x = vv[0];
		target.y = vv[1];
		return ret;
	}

	public static function posInputObj(label:String, target:h2d.Object, format:String = "%.3f", flags:ImGuiInputTextFlags = 0) {
		var vv = arrSingle2;
		vv[0] = target.x;
		vv[1] = target.y;
		ImGui.inputFloat2(label, vv, format, flags);
		target.x = vv[0];
		target.y = vv[1];
	}

	public static function posInput3<T:{ x:Float, y:Float, z:Float }>(label:String, target:T, format:String = "%.3f", flags:ImGuiInputTextFlags = 0) {
		var vv = arrSingle3;
		vv[0] = target.x;
		vv[1] = target.y;
		vv[2] = target.z;
		ImGui.inputFloat3(label, vv, format, flags);
		target.x = vv[0];
		target.y = vv[1];
		target.z = vv[2];
	}

	public static function posInput4<T:{ x:Float, y:Float, z:Float, w:Float }>(label:String, target:T, format:String = "%.3f", flags:ImGuiInputTextFlags = 0) {
		var vv = arrSingle4;
		vv[0] = target.x;
		vv[1] = target.y;
		vv[2] = target.z;
		vv[3] = target.w;
		ImGui.inputFloat3(label, vv, format, flags);
		target.x = vv[0];
		target.y = vv[1];
		target.z = vv[2];
		target.w = vv[3];
	}

	public static function posInputObj3(label:String, target:h3d.scene.Object, format:String = "%.3f", flags:ImGuiInputTextFlags = 0) {
		var vv = arrSingle3;
		vv[0] = target.x;
		vv[1] = target.y;
		vv[2] = target.z;
		ImGui.inputFloat3(label, vv, format, flags);
		target.x = vv[0];
		target.y = vv[1];
		target.z = vv[2];
	}

	public static function sliderDouble(label : String, v : Single, v_min : Single, v_max : Single, format : String = "%.3f", power : Single = 1.0):Float {
		arrSingle1[0] = v;
		ImGui.sliderFloat(label, arrSingle1, v_min, v_max, format, power);
		return arrSingle1[0];
	}

	public static function textInput(label: String, value: String, ?textInputFlags: ImGuiInputTextFlags = 0, ?placeholder: String = null, ?length: Int = 1024): Null<String>
	{
		var textBuf = new hl.Bytes(length);
		var src = haxe.io.Bytes.ofString(value);
		textBuf.blit(0,src,0,value.length);
		textBuf.setUI8(value.length,0); // Null term

		if( placeholder != null )
		{
			if (ImGui.inputTextWithHint(label, placeholder, textBuf, length, textInputFlags)) {
				return @:privateAccess String.fromUTF8(textBuf);
			}
		}
		else
		{

			if (ImGui.inputText(label, textBuf, length, textInputFlags)) {
				return @:privateAccess String.fromUTF8(textBuf);
			}
		}

		return null;
	}


	public static function textInputMultiline(label: String, value: String, ?size: ImVec2 = null, ?textInputFlags: ImGuiInputTextFlags = 0, ?length: Int = 10240 ): Null<String>
	{
		var textBuf = new hl.Bytes(length);
		var src = haxe.io.Bytes.ofString(value);
		textBuf.blit(0,src,0,value.length);
		textBuf.setUI8(value.length,0); // Null term

			if (ImGui.inputTextMultiline(label, textBuf, length, size, textInputFlags)) {
				return @:privateAccess String.fromUTF8(textBuf);
			}
		return null;
	}

	@:generic
	public static function combo<T>(label: String, value: T, type:Dynamic ) : T
	{

		var name = EnumTools.getName( type );
		if(  !typeMap.exists(name))
		{
			var all = haxe.EnumTools.createAll(type);
			var arr = new hl.NativeArray<String>(all.length);

			var ar2 = new Array<Dynamic>();
			for( i in 0...all.length )
			{
				arr[i] = EnumValueTools.getName( all[i] );
				ar2.push( all[i] );
			}

			typeMap[name] = arr;
			enumMap[name] = ar2;

		}

		var options : hl.NativeArray<String> = cast typeMap[name];
		var values = enumMap[name];
		var strSelected = EnumValueTools.getName( cast value );

		var idx = 0;
		for( i in 0 ... options.length )
			if( options[i] == strSelected)
				idx = i;

		if( ImGui.combo(label,idx,options) )
			return values[idx];

		return null;


	}

	public static inline function scaleVec2( vec: ImVec2, scale: Float )
	{
		vec.x = Math.floor( vec.x * scale );
		vec.y = Math.floor( vec.y * scale );
		return vec;
	}

	public static function scaleAllStyle( style: ImGuiStyle, scale: Float )
	{
		style.WindowPadding = scaleVec2( style.WindowPadding, scale );
		style.WindowRounding = Math.floor( style.WindowRounding * scale );
		style.WindowMinSize = scaleVec2( style.WindowMinSize, scale );
		style.ChildRounding = Math.floor( style.ChildRounding * scale );
		style.PopupRounding = Math.floor( style.PopupRounding * scale );
		style.FramePadding = scaleVec2( style.FramePadding, scale );
		style.FrameRounding = Math.floor( style.FrameRounding * scale );
		style.ItemSpacing = scaleVec2( style.ItemSpacing, scale );
		style.ItemInnerSpacing = scaleVec2( style.ItemInnerSpacing, scale );
		style.TouchExtraPadding = scaleVec2( style.TouchExtraPadding, scale );
		style.IndentSpacing = Math.floor( style.IndentSpacing* scale );
		style.ColumnsMinSpacing = Math.floor( style.ColumnsMinSpacing * scale );
		style.ScrollbarSize = Math.floor( style.ScrollbarSize* scale );
		style.ScrollbarRounding = Math.floor( style.ScrollbarRounding * scale );
		style.GrabMinSize = Math.floor( style.GrabMinSize * scale );
		style.GrabRounding = Math.floor( style.GrabRounding * scale );
		//style.LogSliderDeadzone = scaleVec2( style.LogSliderDeadzone, scale );
		style.TabRounding = Math.floor( style.TabRounding * scale );
		style.TabMinWidthForCloseButton = style.TabMinWidthForCloseButton < 5000 ? Math.floor( style.TabRounding * scale ) : style.TabMinWidthForCloseButton;
		style.DisplayWindowPadding = scaleVec2( style.DisplayWindowPadding, scale );
		style.DisplaySafeAreaPadding = scaleVec2( style.DisplaySafeAreaPadding, scale );
		style.MouseCursorScale = Math.floor( style.MouseCursorScale * scale );

	}

	public static function renderTimeline( groups: TimelineGroup )
	{

	}

	#end
}
#end