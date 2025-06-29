#version 320 es
precision mediump float;

#include <flutter/runtime_effect.glsl>

// Flutter-style uniform declarations
layout(location = 0) uniform float uResolutionW;
layout(location = 1) uniform float uResolutionH;
layout(location = 2) uniform float uNumPoints; // Number of control points
uniform sampler2D uControlPointsTexture; // Texture containing control points

vec3 iResolution = vec3(uResolutionW, uResolutionH, 1.0);

layout(location = 0) out vec4 fragColor;

// Author: Thomas Stehle
// Title: SDF Quadratic Bézier Shape
//
// The MIT License
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// Signed distance function for a shape made out of quadratic
// Bézier curves in the tradition of iq's series such as this
// one: https://www.shadertoy.com/view/MlKcDD.
//
// The only real contribution of this shader is that it postpones
// the call to the costly Bézier SDF up until the point it has
// identified the closest segment of the control polygon.
// So instead of iterating over all Bézier curves, we iterate
// over the line segments of the control polygon and identify the
// closest segment. We then call the Bézier SDF for this segment
// only. This approach is correct since quadratic Bézier curves
// are always contained in the triangle formed by its three
// control points.

// Constants
const int CAPACITY = 512; // Control polygon capacity (supports complex glyphs)
const float INF   = 1.0 / 0.0;
const float SQRT3 = 1.732050807568877;

// Utility helpers ------------------------------------------------------------

// Sample the raw texel that stores a control point or a separator. Each pixel
// encodes: R=x, G=y (both in [0,1] space) and B used for meta-data.
vec4 _sampleTexel(int index) {
    float u = (float(index) + 0.5) / uNumPoints; // Center of pixel
    return texture(uControlPointsTexture, vec2(u, 0.5));
}

// Identify separator pixels (blue ≃ 1.0)
bool isSeparator(int idx) {
    return _sampleTexel(idx).b > 0.9;
}

// Orientation is stored in the first pixel of every contour: blue ≃ 0.25 → +1
// (CCW), blue ≃ 0.75 → −1 (CW). Any other pixel returns 0.
float contourOrientation(int idx) {
    float b = _sampleTexel(idx).b;
    if (b > 0.9) return 0.0; // separator
    if (b > 0.5) return -1.0; // CW
    if (b > 0.0) return 1.0;  // CCW (first point)
    return 0.0;               // regular point
}

// Decode control-point coordinates from a texel (regardless of B)
vec2 getPoint(int idx) {
    vec4 t = _sampleTexel(idx);
    return vec2(t.r * 2.0 - 1.0, t.g * 2.0 - 1.0);
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
    float h = saturate(dot(p - a, b - a) /
                       dot(b - a, b - a));
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
// Mostly identical to https://www.shadertoy.com/view/MlKcDD
// with some additions to combat degenerate cases.
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

// Compute the SDF for a single contour that starts at index `startIdx` and has
// `count` control points. Returns both the distance and the closest triple in
// the out-parameters.
float sdf_single_contour(in vec2 p, int startIdx, int count, out vec2 closest[3]) {
    float best = INF;

    // Process all segments including the closing segment
    for (int j = 0; j < count; ++j) {
        vec2 curr = getPoint(startIdx + j);
        vec2 next = getPoint(startIdx + (j + 1) % count);
        vec2 currMid = 0.5 * (curr + next);
        
        // Calculate previous midpoint
        vec2 prevMid;
        if (j == 0) {
            // For first segment, previous midpoint is between last and first point
            vec2 last = getPoint(startIdx + count - 1);
            vec2 first = getPoint(startIdx);
            prevMid = 0.5 * (last + first);
        } else {
            // For other segments, use previous point and current point
            vec2 prevPoint = getPoint(startIdx + j - 1);
            prevMid = 0.5 * (prevPoint + curr);
        }
        
        float ds = sdf_control_segment(p, prevMid, curr, currMid);
        if (abs(ds) < abs(best)) {
            closest[0] = prevMid;
            closest[1] = curr;
            closest[2] = currMid;
            best = ds;
        }
    }

    // Refine distance with quadratic Bézier for the closest triple
    return sdf_bezier(p, closest[0], closest[1], closest[2]);
}

// Winding number calculation for a single Bézier segment
// Returns +1 or -1 for upward/downward crossings, 0 for no crossing
int windingContribution(in vec2 p, in vec2 A, in vec2 B, in vec2 C) {
    // For quadratic Bézier, solve for y-intersections with horizontal ray from p
    float a = A.y - 2.0*B.y + C.y;
    float b = -2.0*A.y + 2.0*B.y;
    float c = A.y - p.y;
    
    if (abs(a) < 1e-8) {
        // Linear case: a ≈ 0, solve bt + c = 0
        if (abs(b) > 1e-8) {
            float t = -c / b;
            if (t >= 0.0 && t <= 1.0) {
                float x = mix(mix(A.x, B.x, t), mix(B.x, C.x, t), t);
                if (x <= p.x) {
                    // Check if going up or down by looking at tangent
                    float dy = mix(B.y, C.y, t) - mix(A.y, B.y, t);
                    return dy > 0.0 ? 1 : -1;
                }
            }
        }
        return 0;
    }
    
    // Quadratic case: solve at² + bt + c = 0
    float discriminant = b*b - 4.0*a*c;
    if (discriminant < 0.0) return 0;
    
    float sqrtD = sqrt(discriminant);
    vec2 t = (-b + vec2(-sqrtD, sqrtD)) / (2.0*a);
    
    int winding = 0;
    
    // Check first root
    if (t.x >= 0.0 && t.x <= 1.0) {
        float x = mix(mix(A.x, B.x, t.x), mix(B.x, C.x, t.x), t.x);
        if (x <= p.x) {
            float dy = mix(B.y, C.y, t.x) - mix(A.y, B.y, t.x);
            winding += dy > 0.0 ? 1 : -1;
        }
    }
    
    // Check second root (only if different from first)
    if (abs(t.y - t.x) > 1e-8 && t.y >= 0.0 && t.y <= 1.0) {
        float x = mix(mix(A.x, B.x, t.y), mix(B.x, C.x, t.y), t.y);
        if (x <= p.x) {
            float dy = mix(B.y, C.y, t.y) - mix(A.y, B.y, t.y);
            winding += dy > 0.0 ? 1 : -1;
        }
    }
    
    return winding;
}

// ---------------------------------------------------------------------------
// Winding number based SDF calculation
// Computes distance to shape using winding numbers (proper hole handling)
float sdf_bezier_shape_multi(in vec2 p, in int totalPoints) {
    float minDistance = INF;
    int windingNumber = 0;

    int i = 0;
    while (i < totalPoints) {
        // Skip consecutive separators, if any
        while (i < totalPoints && isSeparator(i)) { i++; }
        if (i >= totalPoints) break;

        // Contour starts here
        int start = i;

        // Find end (index before next separator or EOS)
        int count = 0;
        while (i < totalPoints && !isSeparator(i)) { i++; count++; }

        // Process all segments in this contour
        for (int j = 0; j < count; ++j) {
            vec2 curr = getPoint(start + j);
            vec2 next = getPoint(start + (j + 1) % count);
            vec2 currMid = 0.5 * (curr + next);
            
            // Calculate previous midpoint
            vec2 prevMid;
            if (j == 0) {
                vec2 last = getPoint(start + count - 1);
                vec2 first = getPoint(start);
                prevMid = 0.5 * (last + first);
            } else {
                vec2 prevPoint = getPoint(start + j - 1);
                prevMid = 0.5 * (prevPoint + curr);
            }
            
            // Distance calculation
            float d = sdf_bezier(p, prevMid, curr, currMid);
            minDistance = min(minDistance, abs(d));
            
            // Winding number calculation
            windingNumber += windingContribution(p, prevMid, curr, currMid);
        }
    }

    // Apply winding number to determine inside/outside
    // Use non-zero rule: inside if winding number != 0
    bool inside = windingNumber != 0;
    return inside ? -minDistance : minDistance;
}

// ---------------------------------------------------------------------------
// Backwards-compat shim (existing calls expect this symbol)
float sdf_bezier_shape(in vec2 p, in int totalPoints) {
    return sdf_bezier_shape_multi(p, totalPoints);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    
    // Pixel coordinates
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    
    int numPoints = int(uNumPoints);
    
    // Distance to shape using general Bézier approach
    float d = sdf_bezier_shape(p, numPoints);
    
    // Distance field
    vec3 col = vec3(1.0) - vec3(0.1,0.4,0.7)*mix(sign(d),1.0,-1.0);
	col *= 1.0 - exp(-4.0*abs(d));
	col *= 0.8 + 0.2*cos(140.0*d);
    
    // Shape
	col = mix(col, vec3(1.0), 1.0-smoothstep(0.0,0.015,abs(d)));
    
    // ---------------- Debug overlay: draw control polygon lines -------------
    float dbg = INF;
    int iDbg = 0;
    while (iDbg < numPoints) {
        while (iDbg < numPoints && isSeparator(iDbg)) iDbg++;
        if (iDbg >= numPoints) break;

        int start = iDbg;
        // Determine contour length
        int cnt = 0;
        while (iDbg < numPoints && !isSeparator(iDbg)) { iDbg++; cnt++; }

        // Need at least 2 points
        if (cnt < 2) continue;

        vec2 first = getPoint(start);
        
        // Handle all segments including the closing segment
        for (int k = 0; k < cnt; ++k) {
            vec2 curr = getPoint(start + k);
            vec2 next = getPoint(start + (k + 1) % cnt);
            vec2 midCurr = 0.5 * (curr + next);
            
            // For the previous midpoint, use either the previous iteration's midNext
            // or for the first iteration, use the midpoint between last and first
            vec2 midPrev;
            if (k == 0) {
                vec2 last = getPoint(start + cnt - 1);
                midPrev = 0.5 * (last + first);
            } else {
                vec2 prevPoint = getPoint(start + k - 1);
                midPrev = 0.5 * (prevPoint + curr);
            }
            
            dbg = abs_min(dbg, sdf_control_segment(p, midPrev, curr, midCurr));
        }
    }

    col = mix(col, vec3(1,0,0), 1.0 - smoothstep(0.0, 0.007, dbg));
    // -------------------------------------------------------------------------
    
    // Output to screen
    fragColor = vec4(col, 1.0);
}