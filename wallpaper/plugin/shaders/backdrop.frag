// Schiefer-Muster: Index-Kachel geräteexakt kacheln und einfärben.
// Jeder Gerätepixel p liest den Kachelpunkt floor(p / pixelScale) mod tileSize (Texelmitte,
// kein Filtern) und setzt die Farbe der Palettenstufe – keine Zwischentöne, keine Unschärfe.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 deviceSize;   // Größe des Elements in Gerätepixeln
    vec2 tileSize;     // Kachelgröße in Texeln
    float pixelScale;  // ganzzahlige Vergrößerung (HiDPI)
    vec4 c0;
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
    vec4 c5;
};

layout(binding = 1) uniform sampler2D tile;

void main()
{
    vec2 p = floor(qt_TexCoord0 * deviceSize);
    vec2 t = mod(floor(p / pixelScale), tileSize);
    float i = floor(texture(tile, (t + 0.5) / tileSize).r * 5.0 + 0.5);
    vec4 c = i < 0.5 ? c0 : i < 1.5 ? c1 : i < 2.5 ? c2 : i < 3.5 ? c3 : i < 4.5 ? c4 : c5;
    fragColor = vec4(c.rgb, 1.0) * qt_Opacity;
}
