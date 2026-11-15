shader_type spatial;
render_mode blend_mix, cull_disabled, depth_prepass_alpha, shadows_disabled, specular_disabled, vertex_lighting;

// Toggle vertex snapping
uniform bool snap_enabled = true;

// Lower values = wobblier
uniform float snap_resolution: hint_range(60.0, 480.0, 1.0) = 148.0;

// Standard texture support
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec2 texture_tile = vec2(1.0, 1.0);

void vertex() {
    // Transform to clip space
    vec4 view_space_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec4 clip_space_pos = PROJECTION_MATRIX * view_space_pos;

    // Snap vertices in screen space
    if (snap_enabled) {
        vec2 ndc = clip_space_pos.xy / clip_space_pos.w;
        ndc = round(ndc * snap_resolution) / snap_resolution;
        clip_space_pos.xy = ndc * clip_space_pos.w;
    }

    POSITION = clip_space_pos;
}

void fragment() {
    // Sample texture normally, no UV distortion
    vec4 albedo = texture(albedo_texture, UV * texture_tile);
    ALBEDO = albedo.rgb;
    ALPHA = albedo.a;
}
