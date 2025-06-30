// Copyright 2025, Tim Lehmann for whynotmake.it
//
// This shader is based on a bunch of sources:
// - https://www.shadertoy.com/view/wccSDf for the refraction
// - https://iquilezles.org/articles/distfunctions2d/ for SDFs
// - Gracious help from @dkwingsmt for the Squircle SDF
//
// Feel free to use this shader in your own projects, it'd be lovely if you could
// give some credit like I did here.

#version 320 es
precision mediump float;

#include <flutter/runtime_effect.glsl>


layout(location = 0) uniform float uSizeW;
layout(location = 1) uniform float uSizeH;

vec2 uSize = vec2(uSizeW, uSizeH);

layout(location = 2) uniform float uChromaticAberration = 0.0;

layout(location = 3) uniform float uGlassColorR;
layout(location = 4) uniform float uGlassColorG;
layout(location = 5) uniform float uGlassColorB;
layout(location = 6) uniform float uGlassColorA;

vec4 uGlassColor = vec4(uGlassColorR, uGlassColorG, uGlassColorB, uGlassColorA);

layout(location = 7) uniform float uLightAngle = 0.785398;
layout(location = 8) uniform float uLightIntensity = 1.0;
layout(location = 9) uniform float uAmbientStrength = 0.1;
layout(location = 10) uniform float uThickness;
layout(location = 11) uniform float uRefractiveIndex = 1.2;

// Control points uniforms
layout(location = 12) uniform float uNumPoints; // Number of control points

layout(binding = 0) uniform sampler2D uBackgroundTexture; // Auto-provided by BackdropFilterLayer
layout(binding = 1) uniform sampler2D uControlPointsTexture; // Texture containing control points
layout(location = 0) out vec4 fragColor;

// Constants for SDF calculation
const float INF = 1.0 / 0.0;
const float SQRT3 = 1.732050807568877;
const float PI = 3.14159265359;
const float EPS = 1e-6; // Epsilon for floating point comparisons

// Fetch a point from the control point texture.
// Decodes the 12-bit packed coordinates and other metadata.
vec4 get_point_data(float index) {
    float u = (index + 0.5) / uNumPoints;
    vec4 texel = texture(uControlPointsTexture, vec2(u, 0.5));
    
    // Decode 12-bit coordinates from RGBA channels
    float x = float(int(texel.r * 255.0) | ((int(texel.b * 255.0) & 0x0F) << 8));
    float y = float(int(texel.g * 255.0) | (((int(texel.b * 255.0) >> 4) & 0x0F) << 8));
    
    return vec4(x, y, 0.0, texel.a); // z is unused, alpha has metadata
}

// Cross-product of two 2D vectors
float cross2(in vec2 a, in vec2 b) {
    return a.x*b.y - a.y*b.x;
}

// Clamp a value to [0, 1]
float saturate(in float a) {
    return clamp(a, 0.0, 1.0);
}
vec3 saturate(in vec3 a) {
    return clamp(a, 0.0, 1.0);
}

// Minimum of the absolute of two values
float abs_min(float a, float b) {
    return abs(a) < abs(b) ? a : b;
}

// SDF for a line segment
float sdf_line(in vec2 p, in vec2 a, in vec2 b) {
    float h = saturate(dot(p - a, b - a) / dot(b - a, b - a));
    return length(p - a - h * (b - a));
}

// Like the SDF for a line but partitioning space into positive and negative
float sdf_line_partition(in vec2 p, in vec2 a, in vec2 b) {
    vec2 ba = b - a;
    vec2 pa = p - a;
    float h = saturate(dot(pa, ba) / dot(ba, ba));
    vec2 k = pa - h * ba;
    vec2 n = vec2(ba.y, -ba.x);
    return (dot(k,n) >= 0.0) ? length(k) : -length(k);
}

// Signed distance to a quadratic Bézier curve
float sdf_bezier(in vec2 pos, in vec2 A, in vec2 B, in vec2 C) {
    const float EPSILON = 1e-3;
    const float ONE_THIRD = 1.0 / 3.0;

    // Handle cases where points coincide
    bool abEqual = all(equal(A, B));
    bool bcEqual = all(equal(B, C));
    bool acEqual = all(equal(A, C));
    
    if (abEqual && bcEqual) {
        return distance(pos, A);
    } else if (abEqual || acEqual) {
        return sdf_line_partition(pos, B, C);
    } else if (bcEqual) {
        return sdf_line_partition(pos, A, C);
    }
    
    // Handle colinear points
    if (abs(dot(normalize(B - A), normalize(C - B)) - 1.0) < EPSILON) {
        return sdf_line_partition(pos, A, C);
    }
    
    vec2 a = B - A;
    vec2 b = A - 2.0*B + C;
    vec2 c = a * 2.0;
    vec2 d = A - pos;

    float kk = 1.0 / dot(b,b);
    float kx = kk * dot(a,b);
    float ky = kk * (2.0*dot(a,a)+dot(d,b)) * ONE_THIRD;
    float kz = kk * dot(d,a);

    float res = 0.0;
    float sgn = 0.0;

    float p = ky - kx*kx;
    float p3 = p*p*p;
    float q = kx*(2.0*kx*kx - 3.0*ky) + kz;
    float h = q*q + 4.0*p3;

    if (h >= 0.0) {
        // One root
        h = sqrt(h);
        vec2 x = 0.5 * (vec2(h, -h) - q);
        vec2 uv = sign(x) * pow(abs(x), vec2(ONE_THIRD));
        float t = saturate(uv.x + uv.y - kx) + EPSILON;
        vec2 q = d + (c + b*t) * t;
        res = dot(q, q);
        sgn = cross2(c + 2.0*b*t, q);
    } else {
        // Three roots
        float z = sqrt(-p);
        float v = acos(q/(p*z*2.0)) * ONE_THIRD;
        float m = cos(v);
        float n = sin(v) * SQRT3;
        vec3 t = saturate(vec3(m+m,-n-m,n-m)*z-kx) + EPSILON;
        vec2 qx = d + (c+b*t.x)*t.x;
        float dx = dot(qx, qx);
        float sx = cross2(c+2.0*b*t.x, qx);
        vec2 qy = d + (c+b*t.y)*t.y;
        float dy = dot(qy, qy);
        float sy = cross2(c+2.0*b*t.y, qy);
        res = (dx < dy) ? dx : dy;
        sgn = (dx < dy) ? sx : sy;
    }
    
    return sign(sgn) * sqrt(res);
}

// Signed distance to a segment of a control polygon
float sdf_control_segment(in vec2 p, in vec2 A, in vec2 B, in vec2 C) {
    return abs_min(sdf_line(p, A, B), sdf_line(p, B, C));
}

// Signed distance to a control polygon
// Identifies and returns distance to the closest segment.
float sdf_control_polygon(in vec2 p, in int controlPolySize, out vec2 closest[3]) {
    // Cycle through segments and track the closest
    float d = INF;
    float ds = 0.0;

    // First n-2 segments
    vec2 c = 0.5 * (get_point_data(0).xy + get_point_data(1).xy);
    vec2 prev = c;
    for (int i = 1; i < controlPolySize - 1; ++i) {
        prev = c;
        c = 0.5 * (get_point_data(i).xy + get_point_data(i+1).xy);
        ds = sdf_control_segment(p, prev, get_point_data(i).xy, c);
        if (abs(ds) < abs(d)) {
            closest[0] = prev;
            closest[1] = get_point_data(i).xy;
            closest[2] = c;
            d = ds;
        }
    }

    // Last-but-one segment
    prev = c;
    c = 0.5 * (get_point_data(controlPolySize-1).xy + get_point_data(0).xy);
    ds = sdf_control_segment(p, prev, get_point_data(controlPolySize-1).xy, c);
    if (abs(ds) < abs(d)) {
        closest[0] = prev;
        closest[1] = get_point_data(controlPolySize-1).xy;
        closest[2] = c;
        d = ds;
    }

    // Last segment
    prev = c;
    c = 0.5 * (get_point_data(0).xy + get_point_data(1).xy);
    ds = sdf_control_segment(p, prev, get_point_data(0).xy, c);
    if (abs(ds) < abs(d)) {
        closest[0] = prev;
        closest[1] = get_point_data(0).xy;
        closest[2] = c;
        d = ds;
    }
    
    // Return distance
    return d;
}

// Signed distance to a quadratic Bezier shape made from a given control polygon
float sdf_bezier_shape(in vec2 p, in int controlPolySize) {
    // Determine closest segment in control polygon
    vec2 closest[3];
    sdf_control_polygon(p, controlPolySize, closest);

    // Refine by determining actual distance to curve of closest segment
    return sdf_bezier(p, closest[0], closest[1], closest[2]);
}

// Calculate the signed distance from a point to a single closed contour
// made of connected quadratic Bézier curves.
float sdf_single_contour(vec2 p, int start_idx, int count) {
    if (count < 2) return 1e6;

    float d = 1e20; // Large value for minimum distance
    int winding_number = 0;

    vec2 p0 = get_point_data(float(start_idx)).xy;

    for (int i = 0; i < count; i += 2) {
        vec2 p1 = get_point_data(float(start_idx + i + 1)).xy;
        vec2 p2 = (i + 2 < count)
            ? get_point_data(float(start_idx + i + 2)).xy
            : p0; // Close the loop

        // Update overall minimum distance
        d = min(d, abs(sdf_bezier(p, p0, p1, p2)));

        // --- Winding number calculation ---
        vec2 a = p0 - p;
        vec2 b = p1 - p;
        vec2 c = p2 - p;

        float angle_a = atan(a.y, a.x);
        float angle_b = atan(b.y, b.x);
        float angle_c = atan(c.y, c.x);

        // Normalize angles to be relative to the start point's angle
        float d_ab = angle_b - angle_a;
        float d_bc = angle_c - angle_b;

        // Wrap angles to [-PI, PI]
        if (d_ab > PI) d_ab -= 2.0 * PI;
        if (d_ab < -PI) d_ab += 2.0 * PI;
        if (d_bc > PI) d_bc -= 2.0 * PI;
        if (d_bc < -PI) d_bc += 2.0 * PI;

        // Simplified root finding for the derivative of the angle
        float t = clamp(dot(a, a-b) / dot(a-b, a-b), 0.0, 1.0);
        float min_angle = angle_a + t * d_ab;
        
        float t2_num = dot(a-b, a-2.0*b+c);
        float t2_den = dot(a-2.0*b+c, a-2.0*b+c);
        
        if (abs(t2_den) > EPS) {
            float t2 = clamp(-t2_num / t2_den, 0.0, 1.0);
            
            vec2 q = (1.0-t2)*(1.0-t2)*a + 2.0*(1.0-t2)*t2*b + t2*t2*c;
            float min_angle_bez = atan(q.y, q.x);

            if (min_angle_bez < min(angle_a, angle_c) || min_angle_bez > max(angle_a, angle_c)) {
                 // ignore
            } else {
                min_angle = min_angle_bez;
            }
        }
        
        bool crosses_positive_ray = (angle_a < 0.0 && angle_c > 0.0 && min_angle < 0.0) ||
                                    (angle_a > 0.0 && angle_c < 0.0 && min_angle > 0.0);

        if (crosses_positive_ray) {
             if (cross2(p1 - p0, p2 - p1) >= 0.0) { // check convexity at join
                 winding_number++;
             } else {
                 winding_number--;
             }
        }

        p0 = p2; // Move to the next start point
    }

    // If winding number is non-zero, we are inside. Negate the distance.
    return (winding_number == 0) ? d : -d;
}

float sceneSDF(vec2 p) {
    int num_pts = int(uNumPoints);
    if (num_pts < 2) {
        // Fallback for empty or invalid data: a large distance, so nothing is rendered.
        return 1e6;
    }

    float d = 1e20; // Initialize with a large distance
    int start_idx = 0;
    int point_count = 0;

    // Loop through all points to find contours separated by a special pixel
    for (int i = 0; i < num_pts; ++i) {
        vec4 pt_data = get_point_data(float(i));
        
        // Alpha == 0 indicates a separator
        if (pt_data.a == 0.0) {
            if (point_count > 0) {
                // Read orientation from the first point's alpha
                float orientation_alpha = get_point_data(float(start_idx)).a;
                float orientation = (orientation_alpha * 255.0 < 128.0) ? 1.0 : -1.0; // CCW < 0.5, CW > 0.5
                
                float contour_sdf = sdf_single_contour(p, start_idx, point_count);

                // Union (min) for outer shapes, subtraction (max) for inner holes
                d = (orientation > 0.0)
                    ? min(d, contour_sdf)
                    : max(d, -contour_sdf);
            }
            start_idx = i + 1;
            point_count = 0;
        } else {
            point_count++;
        }
    }

    // Process the last contour
    if (point_count > 0) {
        float orientation_alpha = get_point_data(float(start_idx)).a;
        float orientation = (orientation_alpha * 255.0 < 128.0) ? 1.0 : -1.0;

        float contour_sdf = sdf_single_contour(p, start_idx, point_count);
        d = (orientation > 0.0)
            ? min(d, contour_sdf)
            : max(d, -contour_sdf);
    }
    
    return d;
}

// Calculate 3D normal using derivatives
vec3 getNormal(float sd, float thickness) {
    float dx = dFdx(sd);
    float dy = dFdy(sd);
    
    // The cosine and sine between normal and the xy plane
    float n_cos = max(thickness + sd, 0.0) / thickness;
    float n_sin = sqrt(max(0.0, 1.0 - n_cos * n_cos));
    
    // Return the normal directly without encoding
    return normalize(vec3(dx * n_cos, dy * n_cos, n_sin));
}

// Calculate height/depth of the liquid surface
float getHeight(float sd, float thickness) {
    if (sd >= 0.0 || thickness <= 0.0) {
        return 0.0;
    }
    if (sd < -thickness) {
        return thickness;
    }
    
    float x = thickness + sd;
    return sqrt(max(0.0, thickness * thickness - x * x));
}

// Calculate lighting effects based on displacement data
vec3 calculateLighting(vec2 uv, vec3 normal, float height, vec2 refractionDisplacement, float thickness) {
    // Basic shape mask
    float normalizedHeight = thickness > 0.0 ? height / thickness : 0.0;
    float shape = smoothstep(0.0, 0.9, 1.0 - normalizedHeight);

    // If we're outside the shape, no lighting.
    if (shape < 0.01) {
        return vec3(0.0);
    }
    
    vec3 viewDir = vec3(0.0, 0.0, 1.0);

    // --- Rim lighting (Fresnel) ---
    // This creates a constant, soft outline.
    float fresnel = pow(1.0 - max(0.0, dot(normal, viewDir)), 3.0);
    vec3 rimLight = vec3(fresnel * uAmbientStrength * 0.5);

    // --- Light-dependent effects ---
    vec3 lightDir = normalize(vec3(cos(uLightAngle), sin(uLightAngle), -0.7));
    vec3 oppositeLightDir = normalize(vec3(-lightDir.xy, lightDir.z));

    // Common vectors needed for both light sources
    vec3 halfwayDir1 = normalize(lightDir + viewDir);
    float specDot1 = max(0.0, dot(normal, halfwayDir1));
    vec3 halfwayDir2 = normalize(oppositeLightDir + viewDir);
    float specDot2 = max(0.0, dot(normal, halfwayDir2));

    // --- Environment Reflection Sampling ---
    // This is used for both the glint and the base reflection for efficiency.
    vec3 reflectedColor = vec3(1.0); // Default to white
    const float reflectionSampleDistance = 300.0;
    const float reflectionBlur = 10.0; // A large blur will wash out distinct colors.

    // Using the normal's XY components provides a more direct "outward" vector
    // than the physically correct reflect() function for this specific visual effect.
    if (length(normal.xy) > 0.001) {
        vec2 reflectionDir = normalize(normal.xy);
        vec2 baseSampleUV = uv + reflectionDir * reflectionSampleDistance / uSize;

        // Simple 4-tap blur for the reflection
        vec2 blurOffset = vec2(reflectionBlur) / uSize;
        vec3 sampledColor = vec3(0.0);
        sampledColor += texture(uBackgroundTexture, baseSampleUV + blurOffset * vec2( 1,  1)).rgb;
        sampledColor += texture(uBackgroundTexture, baseSampleUV + blurOffset * vec2(-1,  1)).rgb;
        sampledColor += texture(uBackgroundTexture, baseSampleUV + blurOffset * vec2( 1, -1)).rgb;
        sampledColor += texture(uBackgroundTexture, baseSampleUV + blurOffset * vec2(-1, -1)).rgb;
        reflectedColor = sampledColor / 4.0;
    }
    
    // 1. Sharp surface glint (tinted by the environment)
    float glintExponent = mix(350.0, 512.0, smoothstep(5.0, 25.0, uThickness));
    float sharpFactor = pow(specDot1, glintExponent) + pow(specDot2, glintExponent * 1.2);

    // First, calculate the pure white glint intensity.
    vec3 whiteGlint = vec3(sharpFactor) * uLightIntensity * 2.5;
    // Then, multiply by the reflected color to tint the glint. This is the key change.
    vec3 sharpGlint = whiteGlint * reflectedColor;

    // 2. Soft internal bleed, controlled by refraction amount
    float displacementMag = length(refractionDisplacement);
    float internalIntensity = smoothstep(5.0, 40.0, displacementMag);
    
    // A very low exponent creates a wide, soft glow.
    float softFactor = pow(specDot1, 32.0) + pow(specDot2, 32.0);
    vec3 softBleed = vec3(softFactor) * uLightIntensity * 0.8;

    // 3. Base Environment Reflection (subtle, always on)
    const float reflectionBase = .1;
    const float reflectionFresnelStrength = 0.5;
    float reflectionFresnel = pow(1.0 - max(0.0, dot(normal, viewDir)), 3.0);
    float reflectionIntensity = reflectionBase + reflectionFresnel * reflectionFresnelStrength;
    vec3 environmentReflection = reflectedColor * reflectionIntensity;

    // Combine lighting components
    vec3 lighting = rimLight + sharpGlint + (softBleed * internalIntensity) + environmentReflection;

    // Final combination
    return lighting * shape;
}

void main() {
    vec2 screenUV = FlutterFragCoord().xy / uSize;
    vec2 p = FlutterFragCoord().xy;
    
    // Generate shape and calculate normal/height directly
    float sd = sceneSDF(p);
    float alpha = smoothstep(-4.0, 0.0, sd);
    
    // If we're completely outside the glass area (with smooth transition)
    if (alpha > 0.999) {
        fragColor = texture(uBackgroundTexture, screenUV);
        return;
    }
    
    // If thickness is effectively zero, behave like a simple blur
    if (uThickness < 0.01) {
        fragColor = texture(uBackgroundTexture, screenUV);
        return;
    }
    
    // Calculate normal and height directly - use normal as is
    vec3 normal = getNormal(sd, uThickness);
    float height = getHeight(sd, uThickness);
    
    // --- Refraction & Chromatic Aberration ---
    float baseHeight = uThickness * 8.0;
    vec3 incident = vec3(0.0, 0.0, -1.0);
    
    vec4 refractColor;
    vec2 refractionDisplacement;

    // To simulate a prism, we calculate refraction separately for each color channel
    // by slightly varying the refractive index.
    if (uChromaticAberration > 0.001) {
        float iorR = uRefractiveIndex - uChromaticAberration * 0.04; // Less deviation for red
        float iorG = uRefractiveIndex;
        float iorB = uRefractiveIndex + uChromaticAberration * 0.08; // More deviation for blue

        // Red channel
        vec3 refractVecR = refract(incident, normal, 1.0 / iorR);
        float refractLengthR = (height + baseHeight) / max(0.001, abs(refractVecR.z));
        vec2 refractedUVR = screenUV + (refractVecR.xy * refractLengthR) / uSize;
        float red = texture(uBackgroundTexture, refractedUVR).r;

        // Green channel (we'll use this for the main displacement and alpha)
        vec3 refractVecG = refract(incident, normal, 1.0 / iorG);
        float refractLengthG = (height + baseHeight) / max(0.001, abs(refractVecG.z));
        refractionDisplacement = refractVecG.xy * refractLengthG; 
        vec2 refractedUVG = screenUV + refractionDisplacement / uSize;
        vec4 greenSample = texture(uBackgroundTexture, refractedUVG);
        float green = greenSample.g;
        float bgAlpha = greenSample.a;

        // Blue channel
        vec3 refractVecB = refract(incident, normal, 1.0 / iorB);
        float refractLengthB = (height + baseHeight) / max(0.001, abs(refractVecB.z));
        vec2 refractedUVB = screenUV + (refractVecB.xy * refractLengthB) / uSize;
        float blue = texture(uBackgroundTexture, refractedUVB).b;
        
        refractColor = vec4(red, green, blue, bgAlpha);
    } else {
        // Default path for no chromatic aberration
        vec3 refractVec = refract(incident, normal, 1.0 / uRefractiveIndex);
        float refractLength = (height + baseHeight) / max(0.001, abs(refractVec.z));
        refractionDisplacement = refractVec.xy * refractLength;
        vec2 refractedUV = screenUV + refractionDisplacement / uSize;
        refractColor = texture(uBackgroundTexture, refractedUV);
    }
    
    // Calculate reflection effect
    vec4 reflectColor = vec4(0.0);
    float reflectionIntensity = clamp(abs(refractionDisplacement.x - refractionDisplacement.y) * 0.001, 0.0, 0.3);
    reflectColor = vec4(reflectionIntensity, reflectionIntensity, reflectionIntensity, 0.0);
    
    // Mix refraction and reflection based on normal.z
    vec4 liquidColor = mix(refractColor, reflectColor, (1.0 - normal.z) * 0.2);
    
    // Calculate lighting effects
    vec3 lighting = calculateLighting(screenUV, normal, height, refractionDisplacement, uThickness);
    
    // Apply realistic glass color influence
    vec4 finalColor = liquidColor;
    
    if (uGlassColor.a > 0.0) {
        float glassLuminance = dot(uGlassColor.rgb, vec3(0.299, 0.587, 0.114));
        
        if (glassLuminance < 0.5) {
            vec3 darkened = liquidColor.rgb * (uGlassColor.rgb * 2.0);
            finalColor.rgb = mix(liquidColor.rgb, darkened, uGlassColor.a);
        } else {
            vec3 invLiquid = vec3(1.0) - liquidColor.rgb;
            vec3 invGlass = vec3(1.0) - uGlassColor.rgb;
            vec3 screened = vec3(1.0) - (invLiquid * invGlass);
            finalColor.rgb = mix(liquidColor.rgb, screened, uGlassColor.a);
        }
        
        finalColor.a = liquidColor.a;
    }
    
    // Add lighting effects to final color
    finalColor.rgb += lighting;
    
    // Sample original background for falloff areas
    vec4 originalBgColor = texture(uBackgroundTexture, screenUV);
    
    // Create falloff effect for areas outside the main liquid glass
    float falloff = clamp(length(refractionDisplacement) / 100.0, 0.0, 1.0) * 0.1 + 0.9;
    vec4 falloffColor = mix(vec4(0.0), originalBgColor, falloff);
    
    // Final mix: blend between displaced liquid color and background based on edge alpha
    finalColor = clamp(finalColor, 0.0, 1.0);
    falloffColor = clamp(falloffColor, 0.0, 1.0);
    
    // Use alpha for smooth transition at boundaries
    vec4 backgroundColor = texture(uBackgroundTexture, screenUV);
    fragColor = mix(backgroundColor, finalColor, 1.0 - alpha);
}
