use godot::prelude::*;

struct GameExtension;

// SAFETY: initialization is delegated to gdext; no manual engine pointers or FFI.
#[gdextension]
unsafe impl ExtensionLibrary for GameExtension {}

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
struct RustProbe;

#[godot_api]
impl RustProbe {
    #[func]
    fn add(&self, a: i32, b: i32) -> i64 {
        add_wide(a, b)
    }
}

fn add_wide(a: i32, b: i32) -> i64 {
    i64::from(a) + i64::from(b)
}

#[cfg(test)]
mod tests {
    use super::add_wide;

    #[test]
    fn addition_is_widened_before_it_can_overflow() {
        assert_eq!(add_wide(20, 22), 42);
        assert_eq!(add_wide(i32::MAX, 1), 2_147_483_648);
        assert_eq!(add_wide(i32::MIN, -1), -2_147_483_649);
    }
}
