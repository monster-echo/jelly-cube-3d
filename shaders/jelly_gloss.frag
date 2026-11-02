#version 320 es

// Jelly Cube 3D — a whisper of procedural studio bloom around the specimen.
// This is additive light only: the software painter remains the material
// fallback and the source of all geometry.
precision highp float;

#include <flutter/runtime_effect.glsl>

layout(location = 0) uniform vec2 uSize;
layout(location = 1) uniform vec2 uCenter;
layout(location = 2) uniform float uRadius;
layout(location = 3) uniform float uTime;
layout(location = 4) uniform vec4 uTint;

layout(location = 0) out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
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

void main() {
  vec2 uv = FlutterFragCoord().xy;
  vec2 p = (uv - uCenter) / max(uRadius, 1.0);
  float r = length(p * vec2(1.0, 0.94));
  float ring = smoothstep(0.74, 1.00, r) * (1.0 - smoothstep(1.02, 1.42, r));
  float veil = (1.0 - smoothstep(0.90, 1.55, r)) * 0.30;
  float n = noise(uv * 0.013 + vec2(uTime * 0.035, -uTime * 0.024));
  float n2 = noise(uv * 0.031 - vec2(uTime * 0.052, uTime * 0.019));
  float caustic = pow(max(0.0, sin((p.x + p.y) * 7.1 + uTime * 1.4) * 0.5 + 0.5), 6.0);
  caustic *= smoothstep(1.34, 0.80, r) * smoothstep(0.25, 0.8, r);
  float alpha = ring * (0.038 + 0.052 * n) + veil * 0.045 + caustic * 0.020 * n2;
  vec3 tint = uTint.rgb * (0.86 + 0.14 * n2);
  fragColor = vec4(tint * alpha, alpha);
}
