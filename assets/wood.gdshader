shader_type canvas_item;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    float grain = sin((uv.x * 42.0) + noise(vec2(uv.x * 10.0, uv.y * 2.0)) * 5.0);
    grain = grain * 0.5 + 0.5;
    float n = noise(uv * vec2(7.0, 28.0));
    float plank = smoothstep(0.0, 0.03, abs(fract(uv.y * 5.0) - 0.5) - 0.47);
    vec3 base = mix(vec3(0.21, 0.095, 0.052), vec3(0.41, 0.19, 0.095), grain * 0.42 + n * 0.20);
    base *= 1.0 - plank * 0.18;
    float vignette = smoothstep(0.92, 0.28, distance(uv, vec2(0.5)));
    base *= mix(0.72, 1.0, vignette);
    COLOR = vec4(base, 1.0);
}
