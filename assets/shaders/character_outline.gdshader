// character_outline.gdshader
// 角色描边轮廓 + 阴影 shader（修复矩形框问题）
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.1, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 2.5;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform vec2 shadow_offset = vec2(2.0, 3.0);

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 uv = UV;

	// 采样原始颜色
	vec4 col = texture(TEXTURE, uv);

	// 阴影：偏移采样（带边界保护）
	vec2 shadow_uv = uv - shadow_offset / tex_size;
	shadow_uv = clamp(shadow_uv, vec2(0.001), vec2(0.999));
	float shadow_alpha = texture(TEXTURE, shadow_uv).a * shadow_color.a;

	// 描边：8方向采样，UV 必须在有效范围内才采样
	float outline_alpha = 0.0;
	float step_x = outline_width / tex_size.x;
	float step_y = outline_width / tex_size.y;

	// UV 边缘保护：离边缘太近不采样，防止矩形框
	float edge_guard = outline_width / min(tex_size.x, tex_size.y) + 0.001;
	bool near_edge = (uv.x < edge_guard || uv.x > 1.0 - edge_guard ||
	                  uv.y < edge_guard || uv.y > 1.0 - edge_guard);

	if (!near_edge) {
		vec2 offsets[8];
		offsets[0] = vec2( step_x,  0.0);
		offsets[1] = vec2(-step_x,  0.0);
		offsets[2] = vec2( 0.0,  step_y);
		offsets[3] = vec2( 0.0, -step_y);
		offsets[4] = vec2( step_x,  step_y);
		offsets[5] = vec2(-step_x,  step_y);
		offsets[6] = vec2( step_x, -step_y);
		offsets[7] = vec2(-step_x, -step_y);
		for (int i = 0; i < 8; i++) {
			vec2 sample_uv = uv + offsets[i];
			// 只在 UV 范围内采样
			if (sample_uv.x > 0.0 && sample_uv.x < 1.0 &&
			    sample_uv.y > 0.0 && sample_uv.y < 1.0) {
				outline_alpha = max(outline_alpha, texture(TEXTURE, sample_uv).a);
			}
		}
		outline_alpha = clamp(outline_alpha - col.a, 0.0, 1.0);
	}

	// 合并：阴影 → 描边 → 原图
	vec4 result = vec4(0.0);
	if (shadow_alpha > 0.01) {
		result = vec4(shadow_color.rgb, shadow_alpha);
	}
	if (outline_alpha * outline_color.a > 0.01) {
		result = mix(result, vec4(outline_color.rgb, 1.0), outline_alpha * outline_color.a);
	}
	result = mix(result, col, col.a);
	COLOR = result;
}
