shader_type canvas_item;

// 破碎效果 shader - 用于地块坍塌动画
// 实现裂纹扩散、碎片分离和向下掉落效果

uniform float crack_progress : hint_range(0.0, 1.0) = 0.0;  // 破碎进度
uniform float fall_offset : hint_range(0.0, 1.0) = 0.0;     // 下落偏移
uniform vec2 crack_center = vec2(0.5, 0.5);                  // 裂纹中心
uniform float crack_density : hint_range(1.0, 20.0) = 8.0;   // 裂纹密度
uniform vec4 crack_color : source_color = vec4(0.3, 0.0, 0.0, 1.0);  // 裂纹颜色

// Simplex 噪声函数 - 用于生成自然的裂纹图案
vec3 permute(vec3 x) { return mod(((x*34.0)+1.0)*x, 289.0); }

float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
            -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy) );
    vec2 x0 = v -   i + dot(i, C.xx);
    vec2 i1;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod(i, 289.0);
    vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
    + i.x + vec3(0.0, i1.x, 1.0 ));
    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),
        dot(x12.zw,x12.zw)), 0.0);
    m = m*m ;
    m = m*m ;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

void fragment() {
    vec2 uv = UV;
    vec4 original_color = texture(TEXTURE, uv);

    // 如果破碎进度为0，直接返回原始颜色
    if (crack_progress <= 0.0) {
        COLOR = original_color;
        return;
    }

    // 计算到裂纹中心的距离
    float dist_to_center = distance(uv, crack_center);

    // 生成径向裂纹图案
    float angle = atan(uv.y - crack_center.y, uv.x - crack_center.x);
    float radial_noise = snoise(vec2(angle * crack_density, dist_to_center * 5.0));

    // 生成随机裂纹图案
    float crack_noise = snoise(uv * 20.0 + vec2(crack_progress * 10.0));

    // 组合裂纹图案
    float crack_pattern = radial_noise * 0.6 + crack_noise * 0.4;

    // 根据破碎进度计算裂纹阈值
    float crack_threshold = 0.3 - crack_progress * 0.5;

    // 裂纹遮罩
    float crack_mask = smoothstep(crack_threshold, crack_threshold + 0.1, crack_pattern);

    // 碎片分离效果 - 根据位置偏移UV
    if (crack_progress > 0.3) {
        float separation = (crack_progress - 0.3) * 2.0;  // 0-1.4
        vec2 offset_dir = normalize(uv - crack_center);
        float offset_amount = crack_pattern * separation * 0.05;
        uv += offset_dir * offset_amount;
    }

    // 重新采样纹理（应用碎片偏移）
    vec4 cracked_color = texture(TEXTURE, uv);

    // 混合裂纹颜色
    vec4 final_color = mix(cracked_color, crack_color, crack_mask * crack_progress);

    // 应用下落偏移（整体向下移动并淡出）
    if (fall_offset > 0.0) {
        // 下落时透明度衰减
        float alpha_fade = 1.0 - fall_offset;
        final_color.a *= alpha_fade;

        // 边缘更快消失
        float edge_fade = 1.0 - smoothstep(0.0, 0.2, max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 2.0);
        final_color.a *= mix(1.0, edge_fade, fall_offset);
    }

    // 破碎边缘高光
    if (crack_progress > 0.0 && crack_progress < 0.8) {
        float edge_highlight = smoothstep(crack_threshold - 0.05, crack_threshold, crack_pattern);
        edge_highlight *= (1.0 - crack_mask);
        final_color.rgb = mix(final_color.rgb, vec3(1.0, 0.5, 0.2), edge_highlight * 0.6);
    }

    COLOR = final_color;
}
