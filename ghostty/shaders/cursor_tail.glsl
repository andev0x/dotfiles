// =============================================================================
// Ghostty Cursor Tail Shader
// Optimized for smooth animation, low GPU overhead, and stable rendering
// =============================================================================

// -----------------------------------------------------------------------------
// sRGB -> Linear conversion
// Ghostty provides colors in sRGB space while shader blending operates in
// linear space. Converting avoids washed-out glow and incorrect alpha blending.
// -----------------------------------------------------------------------------
vec3 sRGBToLinear(vec3 c) {
    return mix(
        c / 12.92,
        pow((c + 0.055) / 1.055, vec3(2.4)),
        step(vec3(0.04045), c)
    );
}

// -----------------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------------

vec4 TRAIL_COLOR = vec4(
    sRGBToLinear(iCurrentCursorColor.rgb),
    iCurrentCursorColor.a
);

// Animation duration in seconds
const float DURATION = 0.06;

// Maximum visible trail length
const float MAX_TRAIL_LENGTH = 0.14;

// Minimum movement required before trail appears
const float THRESHOLD_MIN_DISTANCE = 1.5;

// Anti-aliasing blur radius in pixels
const float BLUR = 1.25;

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------

const float PI = 3.14159265359;

// -----------------------------------------------------------------------------
// Easing Function
// Smooth and responsive easing without heavy pow() usage
// -----------------------------------------------------------------------------

float ease(float x) {
    x = 1.0 - x;
    return sqrt(1.0 - (x * x));
}

// -----------------------------------------------------------------------------
// Rectangle SDF
// -----------------------------------------------------------------------------

float getSdfRectangle(in vec2 p, in vec2 xy, in vec2 b) {
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// -----------------------------------------------------------------------------
// Segment Distance Helper
// Based on Inigo Quilez distance functions
// -----------------------------------------------------------------------------

float seg(in vec2 p, in vec2 a, in vec2 b, inout float s, float d) {
    vec2 e = b - a;
    vec2 w = p - a;

    vec2 proj = a + e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);

    float segd = dot(p - proj, p - proj);

    d = min(d, segd);

    float c0 = step(0.0, p.y - a.y);
    float c1 = 1.0 - step(0.0, p.y - b.y);
    float c2 = 1.0 - step(0.0, e.x * w.y - e.y * w.x);

    float allCond = c0 * c1 * c2;
    float noneCond = (1.0 - c0) * (1.0 - c1) * (1.0 - c2);

    float flip = mix(1.0, -1.0, step(0.5, allCond + noneCond));

    s *= flip;

    return d;
}

// -----------------------------------------------------------------------------
// Parallelogram SDF
// Used for diagonal cursor movement
// -----------------------------------------------------------------------------

float getSdfParallelogram(
    in vec2 p,
    in vec2 v0,
    in vec2 v1,
    in vec2 v2,
    in vec2 v3
) {
    float s = 1.0;
    float d = dot(p - v0, p - v0);

    d = seg(p, v0, v3, s, d);
    d = seg(p, v1, v0, s, d);
    d = seg(p, v2, v1, s, d);
    d = seg(p, v3, v2, s, d);

    return s * sqrt(d);
}

// -----------------------------------------------------------------------------
// Screen Normalization
// Converts pixel coordinates into normalized viewport space
// -----------------------------------------------------------------------------

vec2 normalizeScreen(vec2 value, float isPosition) {
    return (
        (value * 2.0 - (iResolution.xy * isPosition))
        / iResolution.y
    );
}

// -----------------------------------------------------------------------------
// Anti-aliasing
// -----------------------------------------------------------------------------

float antialiasing(float distance, float blurNorm) {
    return 1.0 - smoothstep(
        0.0,
        blurNorm,
        distance
    );
}

// -----------------------------------------------------------------------------
// Detect diagonal direction
// -----------------------------------------------------------------------------

float determineIfTopRightIsLeading(vec2 a, vec2 b) {
    float condition1 = step(b.x, a.x) * step(a.y, b.y);
    float condition2 = step(a.x, b.x) * step(b.y, a.y);

    return 1.0 - max(condition1, condition2);
}

// -----------------------------------------------------------------------------
// Main Shader
// -----------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {

    #if !defined(WEB)
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);
    #endif

    // -------------------------------------------------------------------------
    // Coordinate normalization
    // -------------------------------------------------------------------------

    vec2 vu = normalizeScreen(fragCoord, 1.0);

    vec2 offsetFactor = vec2(-0.5, 0.5);

    vec4 currentCursor = vec4(
        normalizeScreen(iCurrentCursor.xy, 1.0),
        normalizeScreen(iCurrentCursor.zw, 0.0)
    );

    vec4 previousCursor = vec4(
        normalizeScreen(iPreviousCursor.xy, 1.0),
        normalizeScreen(iPreviousCursor.zw, 0.0)
    );

    vec2 centerCC = currentCursor.xy - (currentCursor.zw * offsetFactor);
    vec2 centerCP = previousCursor.xy - (previousCursor.zw * offsetFactor);

    vec2 delta = centerCP - centerCC;

    float lineLength = length(delta);

    vec4 newColor = vec4(fragColor);

    float minDist = currentCursor.w * THRESHOLD_MIN_DISTANCE;

    float blurNorm = (BLUR * 2.0) / iResolution.y;

    // -------------------------------------------------------------------------
    // Draw trail only if movement exceeds threshold
    // -------------------------------------------------------------------------

    if (lineLength > minDist) {

        float progress = clamp(
            (iTime - iTimeCursorChange) / DURATION,
            0.0,
            1.0
        );

        float tailDelayFactor = MAX_TRAIL_LENGTH / lineLength;

        float isLongMove = step(MAX_TRAIL_LENGTH, lineLength);

        float headShort = ease(progress);
        float tailShort = ease(
            smoothstep(tailDelayFactor, 1.0, progress)
        );

        float headLong = 1.0;
        float tailLong = ease(progress);

        float headEased = mix(headLong, headShort, isLongMove);
        float tailEased = mix(tailLong, tailShort, isLongMove);

        float sdfCurrentCursor = getSdfRectangle(
            vu,
            centerCC,
            currentCursor.zw * 0.5
        );

        // ---------------------------------------------------------------------
        // Detect straight movement
        // ---------------------------------------------------------------------

        vec2 deltaAbs = abs(centerCC - centerCP);

        float threshold = 0.003;

        float isHorizontal = step(deltaAbs.y, threshold);
        float isVertical = step(deltaAbs.x, threshold);

        float isStraightMove = max(isHorizontal, isVertical);

        // ---------------------------------------------------------------------
        // Diagonal movement trail
        // ---------------------------------------------------------------------

        vec2 headPosTL = mix(
            previousCursor.xy,
            currentCursor.xy,
            headEased
        );

        vec2 tailPosTL = mix(
            previousCursor.xy,
            currentCursor.xy,
            tailEased
        );

        float isTopRightLeading = determineIfTopRightIsLeading(
            currentCursor.xy,
            previousCursor.xy
        );

        float isBottomLeftLeading = 1.0 - isTopRightLeading;

        vec2 v0 = vec2(
            headPosTL.x + currentCursor.z * isTopRightLeading,
            headPosTL.y - currentCursor.w
        );

        vec2 v1 = vec2(
            headPosTL.x + currentCursor.z * isBottomLeftLeading,
            headPosTL.y
        );

        vec2 v2 = vec2(
            tailPosTL.x + currentCursor.z * isBottomLeftLeading,
            tailPosTL.y
        );

        vec2 v3 = vec2(
            tailPosTL.x + currentCursor.z * isTopRightLeading,
            tailPosTL.y - previousCursor.w
        );

        float sdfTrailDiag = getSdfParallelogram(
            vu,
            v0,
            v1,
            v2,
            v3
        );

        // ---------------------------------------------------------------------
        // Straight movement trail
        // ---------------------------------------------------------------------

        vec2 headCenter = mix(centerCP, centerCC, headEased);
        vec2 tailCenter = mix(centerCP, centerCC, tailEased);

        vec2 minCenter = min(headCenter, tailCenter);
        vec2 maxCenter = max(headCenter, tailCenter);

        vec2 boxSize = (
            maxCenter - minCenter
        ) + currentCursor.zw;

        vec2 boxCenter = (minCenter + maxCenter) * 0.5;

        float sdfTrailRect = getSdfRectangle(
            vu,
            boxCenter,
            boxSize * 0.5
        );

        // ---------------------------------------------------------------------
        // Select final trail shape
        // ---------------------------------------------------------------------

        float sdfTrail = mix(
            sdfTrailDiag,
            sdfTrailRect,
            isStraightMove
        );

        // ---------------------------------------------------------------------
        // Draw trail
        // ---------------------------------------------------------------------

        vec4 trail = TRAIL_COLOR;

        float trailAlpha = antialiasing(sdfTrail, blurNorm);

        newColor = mix(newColor, trail, trailAlpha);

        // ---------------------------------------------------------------------
        // Punch cursor hole to avoid overlap artifacts
        // ---------------------------------------------------------------------

        float hole = smoothstep(
            -0.002,
             0.002,
             sdfCurrentCursor
        );

        newColor = mix(fragColor, newColor, hole);
    }

    fragColor = newColor;
}
