shader_type canvas_item;

uniform float interval = 2.0;

void fragment() {
	float shiner = mod(TIME, interval) - (interval / 4.0);
	COLOR.a *= 1.0 - min((clamp(abs((UV.x) - shiner), 0.0, 1.0) * 2.0), 0.7);
}