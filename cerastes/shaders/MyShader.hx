package cerastes.shaders;

class MyShader extends hxsl.Shader {
    static var SRC = {
        @input var input : { color : Vec4 };
        var output : { color : Vec4 };

        var transformedNormal : Vec3;
        @param var materialColor : Vec4;
        @param var transformMatrix : Mat4;

        function fragment() {
            output.color = materialColor;
        }
    };
}