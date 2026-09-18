package png_tuber

import "core:math/rand"
import la "core:math/linalg"

math_anchor_position :: proc(width, height: f32, anchor: Anchor) -> la.Vector2f32{
	switch anchor{
		case .Top_Left:
			return {0.0, 0.0}
		case .Top_Center:
			return {width/2.0, 0.0}
		case .Top_Right:
			return {width, 0.0}
		case .Center_Left:
			return {0.0, height/2.0}
		case .Center_Center:
			return {width/2.0, height/2.0}
		case .Center_Right:
			return {width, height/2.0}
		case .Bottom_Left:
			return {0.0, height}
		case .Bottom_Center:
			return {width/2.0, height}
		case .Bottom_Right:
			return {width, height}
	}
	return {0.0, 0.0}
}

// Updates object velocity, and returns new displacement
math_damped_oscillator :: proc(
	velocity: ^f32,
	displacement, spring, damp, delta: f32,
) -> (
	new_displacement: f32,
) {
	force := -spring * displacement - damp * velocity^
	velocity^ += force * delta
	new_displacement = displacement + velocity^ * delta
	return new_displacement
}
