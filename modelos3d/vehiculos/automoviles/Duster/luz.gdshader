shader_type spatial;
render_mode blend_add, unshaded, shadows_disabled;

uniform vec4 light_color : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform float brightness : hint_range(0.0, 10.0) = 2.0;
uniform float fade_exponent : hint_range(1.0, 5.0) = 2.5;

void fragment() {
    // Calculamos la intensidad basada en la distancia al centro del cono (UV.x)
    // y a lo largo del cono (UV.y)
    float vertical_fade = pow(1.0 - UV.y, fade_exponent);
    float horizontal_fade = sin(UV.x * PI);
    
    float final_mask = vertical_fade * horizontal_fade;
    
    ALBEDO = light_color.rgb * brightness;
    ALPHA = final_mask * light_color.a;
}