shader_type spatial;

uniform vec3 color_vehiculo : source_color = vec3(0.1, 0.2, 0.5);
uniform float metalicidad : hint_range(0.0, 1.0) = 0.8;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.2;
uniform float brillo_laca : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // Color base
    ALBEDO = color_vehiculo;
    
    // Propiedades físicas de la latonería
    METALLIC = metalicidad;
    ROUGHNESS = rugosidad;
    
    // SPECULAR ayuda a dar ese brillo de reflejo directo
    SPECULAR = brillo_laca;
    
    // Efecto de capa de barniz (Clearcoat)
    // Esto crea el segundo reflejo tipico de los coches
    RIM = 0.5;
    RIM_TINT = 0.2;
}